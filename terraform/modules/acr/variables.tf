variable "name" {
  description = "Globally-unique name of the Azure Container Registry (alphanumeric only, 5-50 chars)."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to place the registry in."
  type        = string
}

variable "location" {
  description = "Azure region for the registry."
  type        = string
}

variable "sku" {
  description = "ACR SKU: Basic, Standard, or Premium."
  type        = string
  default     = "Basic"
}

variable "tags" {
  description = "Tags to apply to the registry."
  type        = map(string)
  default     = {}
}
