resource "azurerm_mssql_server" "this" {
  name                         = var.server_name
  resource_group_name         = var.resource_group_name
  location                    = var.location
  version                     = "12.0"
  administrator_login         = var.administrator_login
  administrator_login_password = var.administrator_login_password
  minimum_tls_version         = "1.2"
  public_network_access_enabled = var.public_network_access_enabled
  tags                        = var.tags
}

resource "azurerm_mssql_database" "this" {
  name           = var.database_name
  server_id      = azurerm_mssql_server.this.id
  sku_name       = var.sku_name
  max_size_gb    = var.max_size_gb
  zone_redundant = false
  tags           = var.tags
}

# Allows other Azure resources (e.g. the App Service) to reach this server.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  count            = var.allow_azure_services ? 1 : 0
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "client_ips" {
  for_each         = var.allowed_client_ips
  name             = "Client-${each.key}"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = each.value
  end_ip_address   = each.value
}
