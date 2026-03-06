# ---------------------------------------------------------------------------
# Enterprise Data Quality Platform — Azure + Databricks (Unity Catalog)
# VNet-injected workspace, Key Vault, ADLS Gen2, Single-Node Spot cluster
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    databricks = { source = "databricks/databricks", version = "~> 1.0" }
  }
}

provider "azurerm" {
  features {}
  # use_oidc = true  # set via ARM_USE_OIDC when using GitHub Actions OIDC
}

# ---------------------------------------------------------------------------
# 1. Resource Group & Networking (VNet injection)
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.project_name}"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnets for Databricks (min /26 each; cannot be shared across workspaces)
resource "azurerm_subnet" "public" {
  name                 = "sub-public"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/26"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private" {
  name                 = "sub-private"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/26"]

  delegation {
    name = "databricks-delegation"
    service_delegation {
      name    = "Microsoft.Databricks/workspaces"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Databricks Workspace (Premium, no public IP)
# ---------------------------------------------------------------------------

resource "azurerm_databricks_workspace" "ws" {
  name                = "ws-${var.project_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "premium"

  custom_parameters {
    no_public_ip        = true
    virtual_network_id  = azurerm_virtual_network.vnet.id
    public_subnet_name  = azurerm_subnet.public.name
    private_subnet_name = azurerm_subnet.private.name
  }

  # Required for Key Vault-backed secret scope (workspace identity reads secrets)
  identity {
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# 3. Azure Key Vault (secret management for Databricks)
# ---------------------------------------------------------------------------

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "kv-${var.project_name}-${substr(md5(azurerm_resource_group.rg.name), 0, 6)}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days   = 7
  purge_protection_enabled    = false

  # Allow Databricks workspace managed identity to read secrets
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_databricks_workspace.ws.identity[0].principal_id
    secret_permissions = ["Get", "List"]
  }

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Recover", "Backup", "Restore"]
  }
}

# ---------------------------------------------------------------------------
# 4. ADLS Gen2 (data landing for DQ and Data Docs)
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "adls" {
  name                     = "st${var.project_name}${substr(md5(azurerm_resource_group.rg.name), 0, 8)}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Required for Gen2
}

resource "azurerm_storage_data_lake_gen2_filesystem" "landing" {
  name               = "landing"
  storage_account_id = azurerm_storage_account.adls.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "data_docs" {
  name               = "data-docs"
  storage_account_id = azurerm_storage_account.adls.id
}

# Grant Databricks workspace identity Storage Blob Data Contributor on the storage account (for reading/writing data and Data Docs)
resource "azurerm_role_assignment" "databricks_storage" {
  scope                = azurerm_storage_account.adls.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_workspace.ws.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# 5. Databricks provider & Key Vault-backed Secret Scope
# ---------------------------------------------------------------------------

provider "databricks" {
  host                        = "https://${azurerm_databricks_workspace.ws.workspace_url}"
  azure_workspace_resource_id = azurerm_databricks_workspace.ws.id
  # Auth: set ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID (or use Azure CLI)
  azure_tenant_id = data.azurerm_client_config.current.tenant_id
}

resource "databricks_secret_scope" "kv" {
  name = "keyvault-managed"
  keyvault_metadata {
    resource_id = azurerm_key_vault.kv.id
    dns_name   = azurerm_key_vault.kv.vault_uri
  }
}

# ---------------------------------------------------------------------------
# 6. Single-Node Databricks cluster (Spot, 20-min autotermination)
# ---------------------------------------------------------------------------

resource "databricks_cluster" "qa_cluster" {
  cluster_name            = "Data-QA-Engine"
  spark_version           = data.databricks_spark_version.latest_lts.id
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 20

  spark_conf = {
    "spark.databricks.cluster.profile" = "singleNode"
    "spark.master"                     = "local[*, 4]"
  }

  azure_attributes {
    availability    = "SPOT_WITH_FALLBACK_AZURE"
    first_on_demand = 1
  }

  num_workers = 0 # Single-node
}

data "databricks_spark_version" "latest_lts" {
  long_term_support = true
}

# ---------------------------------------------------------------------------
# 7. Upload DQ notebook (optional; path must exist)
# ---------------------------------------------------------------------------

resource "databricks_notebook" "qa_notebook" {
  path     = "/Shared/Data_Quality_Check"
  language = "PYTHON"
  source   = "${path.module}/../tests/data_quality_check.py"
}
