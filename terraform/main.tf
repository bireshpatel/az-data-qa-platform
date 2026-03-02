terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.0" }
    databricks = { source = "databricks/databricks", version = "~> 1.0" }
  }
}

provider "azurerm" { features {} }

# 1. Resource Group & Network
resource "azurerm_resource_group" "rg" {
  name     = "rg-data-qa-pro"
  location = "centralus"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-qa"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# (Add Subnets with delegation for Databricks here - use the block from our previous chat)

# 2. Databricks Workspace
resource "azurerm_databricks_workspace" "ws" {
  name                = "ws-data-qa"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "premium"
  custom_parameters {
    no_public_ip       = true
    virtual_network_id = azurerm_virtual_network.vnet.id
    public_subnet_name = "sub-public"
    private_subnet_name = "sub-private"
  }
}

# 3. Low-Cost Cluster
resource "databricks_cluster" "qa_cluster" {
  cluster_name            = "Data-QA-Engine"
  spark_version           = "13.3.x-scala2.12"
  node_type_id            = "Standard_DS3_v2"
  autotermination_minutes = 20
  spark_conf = { "spark.databricks.cluster.profile" : "singleNode", "spark.master" : "local[*]" }
  azure_attributes { availability = "SPOT_WITH_FALLBACK_AZURE", first_on_demand = 1 }
}

# 4. Upload your Data QA Code from the /tests folder
resource "databricks_notebook" "qa_test" {
  path     = "/Shared/Data_Quality_Check"
  language = "PYTHON"
  source   = "../tests/data_quality_check.py" # Points to your Python code
}