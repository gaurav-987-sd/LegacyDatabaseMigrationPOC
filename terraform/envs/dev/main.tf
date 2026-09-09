# Random suffix so globally-unique names (Web App, SQL server, Postgres server,
# Key Vault) don't collide across deployments/environments.
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_password" "sql_admin" {
  length      = 24
  special     = true
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  min_special = 2
  # Azure SQL / Postgres reject a few characters; keep it to a safe set.
  override_special = "!#$%&*()-_=+"
}

resource "random_password" "postgres_admin" {
  length           = 24
  special          = true
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#$%&*()-_=+"
}

resource "random_password" "windows_admin" {
  count            = var.enable_windows_node_pool ? 1 : 0
  length           = 24
  special          = true
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!#$%&*()-_=+"
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  suffix      = random_string.suffix.result

  # Key Vault names are capped at 24 chars total. "kv-" (3) + "-" (1) + a
  # 6-char suffix leaves 14 chars for the prefix; truncate to fit regardless
  # of how long var.project/var.environment are.
  kv_name = "kv-${substr(local.name_prefix, 0, 14)}-${local.suffix}"
}

module "resource_group" {
  source = "../../modules/resource-group"

  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = var.tags
}

module "sql_server" {
  source = "../../modules/sql-server"

  server_name                  = "sql-${local.name_prefix}-${local.suffix}"
  database_name                = "LegacyDatabaseMigrationPOC"
  resource_group_name          = module.resource_group.name
  location                     = module.resource_group.location
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql_admin.result
  sku_name                     = "Basic"
  allow_azure_services         = true
  allowed_client_ips           = var.allowed_client_ips
  tags                         = var.tags
}

module "postgresql" {
  source = "../../modules/postgresql"

  server_name                  = "psql-${local.name_prefix}-${local.suffix}"
  database_name                = "legacydatabasemigrationpoc"
  resource_group_name          = module.resource_group.name
  location                     = module.resource_group.location
  administrator_login          = var.postgres_admin_login
  administrator_login_password = random_password.postgres_admin.result
  sku_name                     = "B_Standard_B1ms"
  allow_azure_services         = true
  allowed_client_ips           = var.allowed_client_ips
  tags                         = var.tags
}

module "app_service" {
  source = "../../modules/app-service"

  name                     = "app-${local.name_prefix}-${local.suffix}"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  sku_name                 = var.app_service_sku
  dotnet_framework_version = "v4.0" # hosts the repo's .NET Framework 4.8 / MVC 5.2.9 app

  # Mirrors Web.config's <connectionStrings>: AppDbConnection now points at
  # Azure SQL, and PostgresConnection is added for the migration target.
  connection_strings = [
    {
      name  = "AppDbConnection"
      type  = "SQLAzure"
      value = module.sql_server.connection_string
    },
    {
      name  = "PostgresConnection"
      type  = "PostgreSQL"
      value = module.postgresql.connection_string
    },
  ]

  app_settings = {
    "ASPNETCORE_ENVIRONMENT" = var.environment
  }

  tags = var.tags
}

module "acr" {
  source = "../../modules/acr"

  name                = "acr${replace(local.name_prefix, "-", "")}${local.suffix}"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  sku                 = var.acr_sku
  tags                = var.tags
}

module "aks" {
  source = "../../modules/aks"

  name                     = "aks-${local.name_prefix}-${local.suffix}"
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  dns_prefix               = "aks-${local.name_prefix}-${local.suffix}"
  sku_tier                 = var.aks_sku_tier
  node_count               = var.aks_node_count
  vm_size                  = var.aks_vm_size
  windows_admin_username   = var.windows_admin_username
  windows_admin_password   = var.enable_windows_node_pool ? coalesce(var.windows_admin_password, random_password.windows_admin[0].result) : null
  enable_windows_node_pool = var.enable_windows_node_pool
  windows_node_count       = var.windows_node_count
  windows_vm_size          = var.windows_vm_size
  tags                     = var.tags
}

# Lets the AKS cluster's own identity pull images from ACR without a
# separate service principal or `az aks update --attach-acr` step.
#
# COMMENTED OUT: our Azure account does not have
# Microsoft.Authorization/roleAssignments/write permission (needs Owner or
# User Access Administrator), so this fails with a 403 AuthorizationFailed.
# Using imagePullSecrets in the k8s deployment manifests instead until an
# admin can grant that permission or create this role assignment manually.
#
#resource "azurerm_role_assignment" "aks_acr_pull" {
#  scope                = module.acr.id
#  role_definition_name = "AcrPull"
#  principal_id         = module.aks.kubelet_identity_object_id
# }
# Lets the CI service principal (used by the image build/push GitHub Actions
# workflow) push new image tags to ACR.
#resource "azurerm_role_assignment" "ci_acr_push" {
#  scope                = module.acr.id
#  role_definition_name = "AcrPush"
#  principal_id         = var.ci_service_principal_object_id
#}

# ---------------------------------------------------------------------------
# Workload Identity: lets pods in AKS (e.g. the app pod, via its
# ServiceAccount) authenticate to Azure as this identity -- no secrets
# stored in Kubernetes. Used by the Secrets Store CSI Driver to pull
# connection strings from Key Vault straight into the pod.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "workload_identity" {
  name                = "id-${local.name_prefix}-${local.suffix}-workload"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "workload_identity_fic" {
  name                = "fic-${local.name_prefix}-app"
  resource_group_name = module.resource_group.name
  parent_id           = azurerm_user_assigned_identity.workload_identity.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = module.aks.oidc_issuer_url
  # Must exactly match namespace/ServiceAccount used in k8s/base/serviceaccount.yaml.
  subject = "system:serviceaccount:${var.app_k8s_namespace}:${var.app_k8s_service_account}"
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                 = local.kv_name
  resource_group_name  = module.resource_group.name
  location             = module.resource_group.location
  reader_principal_ids = [module.app_service.principal_id]

  secrets = {
    "SqlAdminPassword"         = random_password.sql_admin.result
    "PostgresAdminPassword"    = random_password.postgres_admin.result
    "SqlConnectionString"      = module.sql_server.connection_string
    "PostgresConnectionString" = module.postgresql.connection_string
  }

  # Keys of the map above, kept as a separate non-sensitive variable because
  # Terraform forbids using a sensitive value (or anything derived from one)
  # as a for_each argument.
  secret_names = [
    "SqlAdminPassword",
    "PostgresAdminPassword",
    "SqlConnectionString",
    "PostgresConnectionString",
  ]

  tags = var.tags
}
