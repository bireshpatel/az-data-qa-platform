# tests/expectation_suite_builder.py
"""
Builds a reusable Expectation Suite for enterprise DQ checks:
- Nulls (required columns)
- Schema integrity (column set and order)
- Statistical ranges (min/max, value set, etc.)
Unity Catalog–compatible: run on Spark DataFrames loaded via spark.read.table().
"""

import great_expectations as gx
from great_expectations.core.expectation_suite import ExpectationSuite
from great_expectations.core.expectation_configuration import ExpectationConfiguration


def build_dq_expectation_suite(
    context: gx.DataContext,
    suite_name: str = "enterprise_dq_suite",
    required_columns: list | None = None,
    expected_schema_columns: list | None = None,
    numeric_ranges: dict | None = None,
    categorical_allowed_values: dict | None = None,
) -> ExpectationSuite:
    """
    Create or update an Expectation Suite with null, schema, and statistical checks.

    Args:
        context: GX DataContext
        suite_name: Name of the expectation suite
        required_columns: Columns that must have no nulls
        expected_schema_columns: Exact column list for schema check (order matters)
        numeric_ranges: e.g. {"col": {"min": 0, "max": 100}}
        categorical_allowed_values: e.g. {"status": ["active", "inactive"]}
    """
    try:
        suite = context.suites.get(suite_name)
    except Exception:
        suite = context.suites.add(ExpectationSuite(name=suite_name))

    def add(expectation_type: str, **kwargs):
        suite.add_expectation(
            ExpectationConfiguration(expectation_type=expectation_type, kwargs=kwargs)
        )

    # --- Schema integrity ---
    if expected_schema_columns:
        add("expect_table_columns_to_match_ordered_list", column_list=expected_schema_columns)
        add("expect_table_column_count_to_equal", count=len(expected_schema_columns))

    # --- Null checks ---
    if required_columns:
        for col in required_columns:
            add("expect_column_values_to_not_be_null", column=col)

    # --- Statistical ranges (numeric) ---
    if numeric_ranges:
        for col, bounds in numeric_ranges.items():
            min_val = bounds.get("min")
            max_val = bounds.get("max")
            if min_val is not None or max_val is not None:
                add(
                    "expect_column_values_to_be_between",
                    column=col,
                    min_value=min_val,
                    max_value=max_val,
                )

    # --- Categorical / value set (referential-style) ---
    if categorical_allowed_values:
        for col, allowed in categorical_allowed_values.items():
            add("expect_column_values_to_be_in_set", column=col, value_set=allowed)

    # --- Table row count (sanity) ---
    add("expect_table_row_count_to_be_between", min_value=1)

    return suite
