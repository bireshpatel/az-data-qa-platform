# ---------------------------------------------------------------------------
# Outputs for Data QA platform
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.rg.name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL (use for login)"
  value       = "https://${azurerm_databricks_workspace.ws.workspace_url}"
}

output "databricks_workspace_id" {
  description = "Databricks workspace resource ID"
  value       = azurerm_databricks_workspace.ws.id
}

output "key_vault_name" {
  description = "Azure Key Vault name (for secret scope)"
  value       = azurerm_key_vault.kv.name
}

output "key_vault_uri" {
  description = "Azure Key Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "adls_storage_account_name" {
  description = "ADLS Gen2 storage account name"
  value       = azurerm_storage_account.adls.name
}

output "adls_landing_container" {
  description = "ADLS Gen2 container for data landing"
  value       = azurerm_storage_data_lake_gen2_filesystem.landing.name
}

output "adls_data_docs_container" {
  description = "ADLS Gen2 container for Great Expectations Data Docs"
  value       = azurerm_storage_data_lake_gen2_filesystem.data_docs.name
}

output "databricks_secret_scope" {
  description = "Databricks secret scope name (Key Vault-backed)"
  value       = databricks_secret_scope.kv.name
}

output "databricks_cluster_id" {
  description = "Databricks cluster ID for Data QA jobs"
  value       = databricks_cluster.qa_cluster.id
}
