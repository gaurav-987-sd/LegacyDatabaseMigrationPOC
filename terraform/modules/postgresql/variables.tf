variable "server_name" {
  description = "Name of the PostgreSQL Flexible Server (must be globally unique)."
  type        = string
}

variable "database_name" {
  description = "Name of the database that mirrors LegacyDatabaseMigrationPOC for compatibility testing."
  type        = string
  default     = "legacydatabasemigrationpoc"
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "postgres_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "administrator_login" {
  description = "PostgreSQL admin login."
  type        = string
}

variable "administrator_login_password" {
  description = "PostgreSQL admin password. Pass via a secret variable / tfvars that is not committed to source control."
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "Compute SKU, e.g. B_Standard_B1ms for a low-cost POC, GP_Standard_D2s_v3 for general purpose."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB."
  type        = number
  default     = 32768
}

variable "zone" {
  description = "Availability zone for the server."
  type        = string
  default     = "1"
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
  description = "Tags to apply to the PostgreSQL resources."
  type        = map(string)
  default     = {}
}
