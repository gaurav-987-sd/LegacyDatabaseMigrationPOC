output "id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "kubelet_identity_object_id" {
  description = "Object ID of the cluster's kubelet identity, used to grant AcrPull on the registry."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "kube_config_raw" {
  description = "Raw kubeconfig for the cluster (sensitive)."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "host" {
  description = "AKS API server hostname."
  value       = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL, used to set up the federated identity credential for workload identity."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "windows_node_pool_name" {
  description = "Name of the Windows node pool, if enabled."
  value       = var.enable_windows_node_pool ? azurerm_kubernetes_cluster_node_pool.windows[0].name : null
}