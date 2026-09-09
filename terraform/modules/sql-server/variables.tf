variable "server_name" {
  description = "Name of the Azure SQL logical server (must be globally unique)."
  type        = string
}

variable "database_name" {
  description = "Name of the database (matches Web.config's Initial Catalog, e.g. LegacyDatabaseMigrationPOC)."
  type        = string
  default     = "LegacyDatabaseMigrationPOC"
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "administrator_login" {
  description = "SQL admin login."
  type        = string
}

variable "administrator_login_password" {
  description = "SQL admin password. Pass via a secret variable / tfvars that is not committed to source control."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "Database SKU, e.g. Basic, S0, GP_S_Gen5_2. Basic is enough for this POC."
  type        = string
  default     = "Basic"
}

variable "max_size_gb" {
  description = "Max database size in GB."
  type        = number
  default     = 2
}

variable "public_network_access_enabled" {
  description = "Whether the server is reachable over the public internet (in addition to firewall rules)."
  type        = bool
  default     = true
}

variable "allow_azure_services" {
  description = "Add the 0.0.0.0/0.0.0.0 firewall rule that allows traffic from other Azure resources (e.g. App Service)."
  type        = bool
  default     = true
}

variable "allowed_client_ips" {
  description = "Map of label => IP address to allow through the firewall (e.g. developer workstations)."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to the SQL resources."
  type        = map(string)
  default     = {}
}
