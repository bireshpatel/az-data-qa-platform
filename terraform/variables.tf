# ---------------------------------------------------------------------------
# Variables for Enterprise Data Quality platform
# ---------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "centralus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-data-qa-pro"
}

variable "project_name" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "data-qa"
}

# ---------------------------------------------------------------------------
# Backend / state (override via -var or TF_VAR_)
# ---------------------------------------------------------------------------

variable "tf_state_resource_group" {
  description = "Resource group containing the Terraform state storage account"
  type        = string
  default     = ""
}

variable "tf_state_storage_account" {
  description = "Storage account name for Terraform state"
  type        = string
  default     = ""
}

variable "tf_state_container" {
  description = "Container name for Terraform state"
  type        = string
  default     = "tfstate"
}

variable "tf_state_key" {
  description = "State file key (path) within the container"
  type        = string
  default     = "data-qa-platform.tfstate"
}
