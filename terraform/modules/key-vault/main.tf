data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                       = var.name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # disabled for easy POC teardown; enable for production
  tags                       = var.tags

  # Access for whoever/whatever is running Terraform, so secrets below can be written.
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover",
    ]
  }

  dynamic "access_policy" {
    for_each = var.reader_principal_ids
    content {
      tenant_id = data.azurerm_client_config.current.tenant_id
      object_id = access_policy.value

      secret_permissions = ["Get", "List"]
    }
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each     = var.secret_names
  name         = each.value
  value        = var.secrets[each.value]
  key_vault_id = azurerm_key_vault.this.id
}
