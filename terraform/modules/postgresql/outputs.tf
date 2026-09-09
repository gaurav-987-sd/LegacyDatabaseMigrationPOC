output "server_id" {
  description = "Resource ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "server_fqdn" {
  description = "Fully qualified domain name of the PostgreSQL server."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "database_name" {
  description = "Name of the database."
  value       = azurerm_postgresql_flexible_server_database.this.name
}

output "connection_string" {
  description = "Npgsql-style connection string for the PostgreSQL migration target."
  value       = "Host=${azurerm_postgresql_flexible_server.this.fqdn};Port=5432;Database=${azurerm_postgresql_flexible_server_database.this.name};Username=${var.administrator_login};Password=${var.administrator_login_password};Ssl Mode=Require;Trust Server Certificate=true;"
  sensitive   = true
}
