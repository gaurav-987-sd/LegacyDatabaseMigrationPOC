variable "project" {
  description = "Short project slug used to build resource names."
  type        = string
  default     = "legacydbmig"
}
variable "environment" {
  description = "Environment name (dev, test, prod...)."
  type        = string
  default     = "dev"
}
variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}
variable "app_service_sku" {
  description = "App Service Plan SKU. F1 (Free) avoids dedicated vCPU quota; switch to B1+ once quota is granted."
  type        = string
  default     = "F1"
}
variable "sql_admin_login" {
  description = "Admin username for the Azure SQL server."
  type        = string
  default     = "sqladmin"
}
variable "postgres_admin_login" {
  description = "Admin username for the PostgreSQL flexible server."
  type        = string
  default     = "pgadmin"
}
variable "acr_sku" {
  description = "Azure Container Registry SKU: Basic, Standard, or Premium."
  type        = string
  default     = "Basic"
}
variable "aks_sku_tier" {
  description = "AKS control-plane SKU tier: Free (no SLA, no cost) or Standard."
  type        = string
  default     = "Free"
}
variable "aks_node_count" {
  description = "Number of nodes in the AKS default node pool."
  type        = number
  default     = 1
}
variable "aks_vm_size" {
  description = "VM size for AKS nodes."
  type        = string
  default     = "Standard_B2s"
}
variable "allowed_client_ips" {
  description = "Map of label => IP address allowed through both database firewalls (e.g. your workstation for local testing)."
  type        = map(string)
  default     = {}
}
variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    Project = "LegacyDatabaseMigrationPOC"
    Purpose = "MSSQL-to-PostgreSQL-migration-poc"
  }
}
variable "windows_admin_username" {
  type    = string
  default = "azureuser"
}
variable "windows_admin_password" {
  type      = string
  default   = null
  sensitive = true
}
variable "enable_windows_node_pool" {
  description = "Create the optional Windows AKS node pool. Enable only when the subscription has a compatible Windows VM size and quota."
  type        = bool
  default     = false
}
variable "windows_node_count" {
  type    = number
  default = 1
}
variable "windows_vm_size" {
  type    = string
  default = "Standard_D2as_v7"
}

variable "ci_service_principal_object_id" {
  description = "Object ID of the service principal used by the GitHub Actions image build/push workflow. Get it with: az ad sp show --id <clientId> --query id -o tsv"
  type        = string
}

variable "app_k8s_namespace" {
  description = "Kubernetes namespace the app is deployed into (must match k8s/base/namespace.yaml)."
  type        = string
  default     = "legacydbmig"
}

variable "app_k8s_service_account" {
  description = "Kubernetes ServiceAccount name used by the app pods (must match k8s/base/serviceaccount.yaml)."
  type        = string
  default     = "legacydbmig-sa"
}