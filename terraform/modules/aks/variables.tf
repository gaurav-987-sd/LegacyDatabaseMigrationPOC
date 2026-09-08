variable "name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to place the cluster in."
  type        = string
}

variable "location" {
  description = "Azure region for the cluster."
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster's API server (must be unique-ish, letters/numbers/hyphens)."
  type        = string
}

variable "sku_tier" {
  description = "AKS control-plane SKU tier: Free (no SLA, no cost) or Standard (SLA-backed, paid)."
  type        = string
  default     = "Free"
}

variable "node_count" {
  description = "Number of nodes in the default system node pool."
  type        = number
  default     = 1
}

variable "vm_size" {
  description = "VM size for the default node pool."
  type        = string
  default     = "Standard_B2ms"
}

variable "tags" {
  description = "Tags to apply to the cluster."
  type        = map(string)
  default     = {}
}

variable "windows_admin_username" {
  description = "Admin username for Windows nodes."
  type        = string
  default     = "azureuser"
}

variable "windows_admin_password" {
  description = "Admin password for Windows nodes (12+ chars, upper/lower/number/symbol)."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_windows_node_pool" {
  description = "Whether to create the optional Windows node pool."
  type        = bool
  default     = false
}

variable "windows_node_count" {
  description = "Number of Windows nodes."
  type        = number
  default     = 1
}

variable "windows_vm_size" {
  description = "VM size for Windows nodes."
  type        = string
  default     = "Standard_D2as_v7"
}

variable "enable_workload_identity" {
  description = "Enable OIDC issuer + Azure AD Workload Identity, so pods can authenticate to Azure (e.g. Key Vault) without stored credentials."
  type        = bool
  default     = true
}
