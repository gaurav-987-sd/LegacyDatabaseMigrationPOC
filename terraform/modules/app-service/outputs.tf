output "id" {
  description = "Resource ID of the Web App."
  value       = azurerm_windows_web_app.this.id
}

output "name" {
  description = "Name of the Web App."
  value       = azurerm_windows_web_app.this.name
}

output "default_hostname" {
  description = "Default *.azurewebsites.net hostname."
  value       = azurerm_windows_web_app.this.default_hostname
}

output "principal_id" {
  description = "Object ID of the Web App's system-assigned managed identity, for Key Vault access policies."
  value       = azurerm_windows_web_app.this.identity[0].principal_id
}

output "service_plan_id" {
  description = "Resource ID of the App Service Plan."
  value       = azurerm_service_plan.this.id
}
