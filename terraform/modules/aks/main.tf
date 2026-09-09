resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  dns_prefix          = var.dns_prefix

  sku_tier            = var.sku_tier

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.vm_size
    os_sku     = "AzureLinux"
  }

  identity {
    type = "SystemAssigned"
  }

  # Azure CNI Overlay is required for Windows node pools (kubenet is not supported).
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
  }

  dynamic "windows_profile" {
    for_each = var.enable_windows_node_pool ? [1] : []
    content {
      admin_username = var.windows_admin_username
      admin_password = var.windows_admin_password
    }
  }
  # Lets pods authenticate to Azure (Key Vault, etc.) as a real Azure AD
  # identity via a federated credential, instead of storing a secret in a
  # Kubernetes Secret. Used by the Secrets Store CSI Driver setup below.
  oidc_issuer_enabled       = var.enable_workload_identity
  workload_identity_enabled = var.enable_workload_identity
  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "windows" {
  count                 = var.enable_windows_node_pool ? 1 : 0
  name                  = "winnp"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.windows_vm_size
  node_count            = var.windows_node_count
  os_type               = "Windows"
  os_sku                = "Windows2022"
  mode                  = "User"

  node_taints = ["os=windows:NoSchedule"]

  tags = var.tags

  lifecycle {
    ignore_changes = [
      windows_profile,
      upgrade_settings,
      max_count,
      min_count,
      zones,
    ]
  }
}

