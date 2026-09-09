variable "name" {
  description = "Name of the Web App (must be globally unique, becomes <name>.azurewebsites.net)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "sku_name" {
  description = "App Service Plan SKU (e.g. B1, S1, P1v3). B1 is enough for this POC."
  type        = string
  default     = "B1"
}

variable "always_on" {
  description = "Keep the app warm. Not supported on Free/Shared tiers."
  type        = bool
  default     = true
}

variable "dotnet_framework_version" {
  description = "dotnet_version for the application_stack block. Use \"v4.0\" for .NET Framework 4.x (this repo targets 4.8)."
  type        = string
  default     = "v4.0"
}

variable "app_settings" {
  description = "Extra app settings (key/value) to merge into the Web App."
  type        = map(string)
  default     = {}
}

variable "connection_strings" {
  description = "Connection strings to expose to the app, e.g. AppDbConnection (SQLServer) and PostgresConnection (PostgreSQL)."
  type = list(object({
    name  = string
    type  = string # "SQLServer", "PostgreSQL", "Custom", etc.
    value = string
  }))
  default = []
}

variable "vnet_integration_subnet_id" {
  description = "Optional subnet ID for VNet integration (e.g. to reach a private database endpoint). Leave null to skip."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the App Service resources."
  type        = map(string)
  default     = {}
}
