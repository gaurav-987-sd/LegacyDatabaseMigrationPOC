output "server_id" {
  description = "Resource ID of the SQL logical server."
  value       = azurerm_mssql_server.this.id
}

output "server_fqdn" {
  description = "Fully qualified domain name of the SQL server."
  value       = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "database_id" {
  description = "Resource ID of the database."
  value       = azurerm_mssql_database.this.id
}

output "database_name" {
  description = "Name of the database."
  value       = azurerm_mssql_database.this.name
}

output "connection_string" {
  description = "ADO.NET-style connection string equivalent to the AppDbConnection entry in Web.config, pointed at Azure SQL instead of localhost."
  value       = "Server=tcp:${azurerm_mssql_server.this.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.this.name};Persist Security Info=False;User ID=${var.administrator_login};Password=${var.administrator_login_password};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  sensitive   = true
}
