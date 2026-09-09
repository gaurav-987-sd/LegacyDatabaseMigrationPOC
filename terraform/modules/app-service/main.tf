resource "azurerm_service_plan" "this" {
  name                = "${var.name}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Windows" # required for classic .NET Framework 4.8 / MVC 5 workloads
  sku_name            = var.sku_name
  tags                = var.tags
}

resource "azurerm_windows_web_app" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = var.always_on

    application_stack {
      current_stack  = "dotnet"
      dotnet_version = var.dotnet_framework_version # "v4.0" runs .NET Framework 4.8 on the App Service platform
    }

    ftps_state             = "Disabled"
    minimum_tls_version    = "1.2"
    http2_enabled          = true
    vnet_route_all_enabled = var.vnet_integration_subnet_id != null
  }

  app_settings = merge(
    {
      "WEBSITE_RUN_FROM_PACKAGE" = "1"
    },
    var.app_settings
  )

  # Connection strings are injected here rather than in the repo's Web.config,
  # so Azure overrides AppDbConnection (SQL Server) at runtime and adds the
  # PostgreSQL target connection used for migration testing.
  dynamic "connection_string" {
    for_each = var.connection_strings
    content {
      name  = connection_string.value.name
      type  = connection_string.value.type
      value = connection_string.value.value
    }
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"], # updated by CI/CD deploys
    ]
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "this" {
  count          = var.vnet_integration_subnet_id != null ? 1 : 0
  app_service_id = azurerm_windows_web_app.this.id
  subnet_id      = var.vnet_integration_subnet_id
}
