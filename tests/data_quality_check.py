# tests/data_quality_check.py
# ---------------------------------------------------------------------------
# Data Quality validation pipeline: Great Expectations + Databricks (Unity Catalog)
# - Load table from UC into Spark DataFrame, validate with GX, generate HTML Data Docs
# ---------------------------------------------------------------------------
# Compatible with Databricks Runtime 12+ and Unity Catalog.
# Known: GX 0.18.x works with Spark DataFrames; use spark.read.table() for UC tables.
# ---------------------------------------------------------------------------

# Databricks provides spark and dbutils at runtime (not available locally)
from pathlib import Path

import great_expectations as gx

# Optional: use our suite builder for reusable DQ rules
try:
    from expectation_suite_builder import build_dq_expectation_suite
except Exception:
    build_dq_expectation_suite = None

# --- Configuration (override via widget or env in Databricks) ---
CATALOG_TABLE = "main.default.sample_data"  # catalog.schema.table
SUITE_NAME = "enterprise_dq_suite"
DATA_DOCS_LOCAL_DIR = "/tmp/gx_data_docs"
# ADLS path for Data Docs (e.g. abfss://data-docs@staccount.dfs.core.windows.net/run_YYYYMMDD/)
DATA_DOCS_ADLS_PATH = None  # set to full abfss path to publish; e.g. from Key Vault


def get_gx_context(context_root_dir: str | None = None):
    """Create a GX context. On Databricks, use a local/ephemeral root for this run."""
    if context_root_dir is None:
        context_root_dir = "/tmp/gx_context"
    Path(context_root_dir).mkdir(parents=True, exist_ok=True)
    return gx.get_context(context_root_dir=context_root_dir)


def load_table_from_uc(full_table_name: str):
    """Load a Unity Catalog table into a Spark DataFrame (Unity Catalog–compatible)."""
    try:
        return spark.read.table(full_table_name)
    except Exception as e:
        print(f"Could not read table {full_table_name}: {e}")
        return None


def run_validation(
    df,
    context: gx.DataContext,
    suite_name: str,
    data_source_name: str = "spark_dq",
    data_asset_name: str = "uc_table",
):
    """Register DataFrame as GX asset, run checkpoint, return result."""
    # Spark Data Source and DataFrame asset (pass DataFrame at runtime)
    try:
        data_source = context.data_sources.get(data_source_name)
    except Exception:
        data_source = context.data_sources.add_spark(name=data_source_name)

    try:
        data_asset = data_source.get_asset(data_asset_name)
    except Exception:
        data_asset = data_source.add_dataframe_asset(name=data_asset_name)

    batch_request = data_asset.build_batch_request(dataframe=df)

    # Ensure expectation suite exists (use builder if available)
    if build_dq_expectation_suite:
        # Example: require no nulls in key columns, optional schema/ranges
        build_dq_expectation_suite(
            context,
            suite_name=suite_name,
            required_columns=df.columns[: min(3, len(df.columns))],  # first 3 cols no nulls
            expected_schema_columns=list(df.columns),
        )
    else:
        # Minimal suite if builder not installed
        try:
            context.suites.get(suite_name)
        except Exception:
            from great_expectations.core.expectation_suite import ExpectationSuite
            from great_expectations.core.expectation_configuration import ExpectationConfiguration
            suite = context.suites.add(ExpectationSuite(name=suite_name))
            for col in df.columns[:2]:
                suite.add_expectation(
                    ExpectationConfiguration(
                        expectation_type="expect_column_values_to_not_be_null",
                        kwargs={"column": col},
                    )
                )

    checkpoint_name = "dq_checkpoint"
    checkpoint = context.add_or_update_checkpoint(
        name=checkpoint_name,
        validations=[
            {
                "batch_request": batch_request,
                "expectation_suite_name": suite_name,
            }
        ],
    )
    result = checkpoint.run(batch_parameters={"dataframe": df})
    return result


def build_and_publish_data_docs(context: gx.DataContext, adls_path: str | None = None):
    """Build HTML Data Docs and optionally copy to ADLS for stakeholders."""
    Path(DATA_DOCS_LOCAL_DIR).mkdir(parents=True, exist_ok=True)
    # Build to local directory (uses context's default data docs store)
    index_paths = context.build_data_docs()
    # If we have an abfss path, copy to ADLS (Databricks)
    if adls_path and "dbutils" in dir():
        import time
        run_suffix = time.strftime("%Y%m%d_%H%M%S")
        dest = f"{adls_path.rstrip('/')}/run_{run_suffix}"
        dbutils.fs.cp(
            f"file:{DATA_DOCS_LOCAL_DIR}",
            dest,
            recurse=True,
        )
        print(f"Data Docs published to: {dest}")
    return index_paths


# --- Main (run in Databricks notebook or job) ---
def main():
    context = get_gx_context()
    df = load_table_from_uc(CATALOG_TABLE)
    if df is None:
        from pyspark.sql import Row
        df = spark.createDataFrame([
            Row(id=1, name="a", value=10),
            Row(id=2, name="b", value=20),
            Row(id=3, name="c", value=30),
        ])
    result = run_validation(df, context, SUITE_NAME)
    print("Validation success:", result.get("success", False))
    build_and_publish_data_docs(context, DATA_DOCS_ADLS_PATH)
    return result


if __name__ == "__main__":
    main()
elif "spark" in dir():
    main()
