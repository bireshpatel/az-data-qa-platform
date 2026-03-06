# ---------------------------------------------------------------------------
# Azure RM Backend for Terraform state (portable across Azure accounts)
# ---------------------------------------------------------------------------
# To use: terraform init -backend-config=backend.hcl
# Or set env vars: ARM_USE_OIDC=true when using GitHub Actions OIDC
# ---------------------------------------------------------------------------

terraform {
  backend "azurerm" {
    # resource_group_name  = ""  # set via -backend-config or backend.hcl
    # storage_account_name = ""
    # container_name       = "tfstate"
    # key                  = "data-qa-platform.tfstate"
    # use_oidc             = true  # when using GitHub Actions OIDC
  }
}
