# az-data-qa-platform

Repository for Data QA / data-quality tooling and Terraform infra for the Azure Data QA platform.

Contents
- `terraform/` — Terraform configuration for provisioning resources.
- `tests/` — Data quality tests and utilities.

Getting started
1. Inspect `terraform/` for infrastructure definitions.
2. Use a Python virtual environment for running tests:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```
