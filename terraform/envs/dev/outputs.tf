output "resource_group_name" {
  value = module.resource_group.name
}

output "web_app_url" {
  description = "URL of the deployed ASP.NET MVC app."
  value       = "https://${module.app_service.default_hostname}"
}

output "acr_login_server" {
  description = "ACR login server \u2014 use this as the prefix for Docker image tags."
  value       = module.acr.login_server
}

output "aks_cluster_name" {
  value = module.aks.name
}

output "sql_server_fqdn" {
  value = module.sql_server.server_fqdn
}

output "postgres_server_fqdn" {
  value = module.postgresql.server_fqdn
}

output "key_vault_uri" {
  value = module.key_vault.vault_uri
}

output "sql_admin_login" {
  value = var.sql_admin_login
}

output "postgres_admin_login" {
  value = var.postgres_admin_login
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the AKS cluster, used for workload identity federation."
  value       = module.aks.oidc_issuer_url
}

output "workload_identity_client_id" {
  description = "Client ID of the user-assigned identity used for AKS workload identity (pod -> Key Vault auth)."
  value       = azurerm_user_assigned_identity.workload_identity.client_id
}
