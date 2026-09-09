project              = "legacydbmig"
environment          = "dev"
location             = "centralus"
app_service_sku      = "B1"
sql_admin_login      = "sqladmin"
postgres_admin_login = "pgadmin"
# Add your workstation's public IP here to reach the databases directly for testing.
allowed_client_ips = {
  "my-laptop" = "223.181.41.207"
}
acr_sku                  = "Basic"
aks_sku_tier             = "Free"
aks_node_count           = 1
aks_vm_size              = "Standard_D2as_v7"
enable_windows_node_pool = true
windows_vm_size          = "Standard_D2as_v7"
app_k8s_namespace       = "legacydbmig"
app_k8s_service_account = "legacydbmig-sa"
ci_service_principal_object_id = "b005c5a9-b1f3-4c14-a581-683e3b07bf25"
tags = {
  Project = "LegacyDatabaseMigrationPOC"
  Purpose = "MSSQL-to-PostgreSQL-migration-poc"
  Owner   = "gaurav"
}
