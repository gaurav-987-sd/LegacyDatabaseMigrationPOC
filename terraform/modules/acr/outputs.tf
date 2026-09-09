output "id" {
  description = "Resource ID of the container registry."
  value       = azurerm_container_registry.this.id
}

output "name" {
  description = "Name of the container registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server hostname (e.g. myregistry.azurecr.io) used in Docker image tags."
  value       = azurerm_container_registry.this.login_server
}
