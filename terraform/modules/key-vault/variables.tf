variable "name" {
  description = "Name of the Key Vault (must be globally unique, 3-24 chars)."
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

variable "secrets" {
  description = "Map of secret name => value to store, e.g. SQL and PostgreSQL connection strings. Only the values are treated as sensitive; the names (map keys) are used for for_each and must not be sensitive themselves."
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "secret_names" {
  description = "Non-sensitive set of the keys in var.secrets. Terraform forbids using a sensitive value in for_each, so the names are passed separately here and the (sensitive) values are looked up via var.secrets[each.value]."
  type        = set(string)
  default     = []
}

variable "reader_principal_ids" {
  description = "Object IDs (e.g. an App Service's managed identity principal_id) granted Get/List on secrets."
  type        = set(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the Key Vault."
  type        = map(string)
  default     = {}
}
