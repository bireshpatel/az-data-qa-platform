# az-data-qa-platform

Enterprise Data Quality (DQ) POC on Azure: **Great Expectations**, **Databricks** (Unity Catalog), and **Azure** (Key Vault, ADLS Gen2). Client-ready demo for data validation with HTML Data Docs.

## Contents

| Path | Description |
|------|-------------|
| `terraform/` | VNet-injected Databricks, Key Vault, ADLS Gen2, Secret Scope, single-node Spot cluster |
| `tests/` | Great Expectations validation pipeline, expectation suite builder, sample DQ checks |
| `.github/workflows/deploy.yml` | GitHub Actions: OIDC + Terraform apply with Azure RM backend |

## Infrastructure (Terraform)

- **Networking**: VNet with two delegated subnets (`sub-public`, `sub-private`) for Azure Databricks (no public IP).
- **Workspace**: Azure Databricks Premium, VNet-injected (`no_public_ip = true`).
- **Security**: Azure Key Vault with access for the Databricks workspace identity; Key Vault–backed **Databricks Secret Scope** (`keyvault-managed`).
- **Storage**: ADLS Gen2 storage account with containers `landing` (data) and `data-docs` (Great Expectations HTML reports).
- **Compute**: Single-node cluster, **SPOT_WITH_FALLBACK_AZURE**, 20-minute autotermination.

### Backend (state)

Terraform state is stored in **Azure RM** for portability. Configure via `backend.hcl` (copy from `backend.hcl.example`) or CI:

- `resource_group_name`, `storage_account_name`, `container_name`, `key`
- For GitHub Actions OIDC: `use_oidc = true`

```bash
cd terraform
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Data Quality (Great Expectations + Unity Catalog)

**Compatibility**: Use **GX 0.18.x** with Databricks Runtime 12+ and Unity Catalog. Data is loaded with `spark.read.table("catalog.schema.table")` into a Spark DataFrame, then passed to the GX **Spark** execution engine. Avoid the `gx` (2.x) package for this pattern.

- **Expectation Suite**: nulls, schema (column list/count), statistical ranges (min/max), value set (referential-style). See `tests/expectation_suite_builder.py`.
- **Pipeline**: `tests/data_quality_check.py` — load UC table → run checkpoint → generate HTML Data Docs → optionally copy to ADLS (`data-docs` container) for stakeholders.

### Running on Databricks

1. Install Great Expectations on the cluster (e.g. init script or `%pip install great_expectations>=0.18,<0.19`).
2. Set `CATALOG_TABLE` (e.g. `main.default.sample_data`) and optionally `DATA_DOCS_ADLS_PATH` (e.g. `abfss://data-docs@<storage_account>.dfs.core.windows.net/`).
3. Run the notebook/job; Data Docs are built and can be copied to ADLS for sharing.

### Known compatibility

- **Unity Catalog**: GX does not connect to UC directly; always use `spark.read.table()` then GX Spark datasource/DataFrame asset.
- **GX 2.x (gx package)**: Different API; this repo targets the classic `great_expectations` 0.18.x API.

## Automation (GitHub Actions)

`deploy.yml` runs `terraform apply` on push to `main` (and on `workflow_dispatch`).

- **Auth**: **OIDC** with Azure (no client secret). Configure an Azure AD App Registration with a **federated credential** (see [docs/AZURE_OIDC_SETUP.md](docs/AZURE_OIDC_SETUP.md) for step-by-step setup and troubleshooting):
  - Issuer: `https://token.actions.githubusercontent.com`
  - Audience: `api://AzureADTokenExchange`
  - Subject: `repo:<org>/<repo>:ref:refs/heads/main` (or environment).
- **Secrets**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`; for remote state: `TF_STATE_RG`, `TF_STATE_SA`, and optionally `TF_STATE_CONTAINER`, `TF_STATE_KEY`.

Create the state storage account and container in Azure, then set the listed secrets in the repo.

## Getting started (local)

```bash
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements.txt
# Run Terraform from terraform/ with backend configured; run GX pipeline on Databricks.
```
