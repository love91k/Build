
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "az_kv" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_enabled         = var.soft_delete_enabled
  purge_protection_enabled    = var.purge_protection_enabled
  sku_name                    = "standard"

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_key_vault_access_policy" "current_client_policy" {
  key_vault_id            = azurerm_key_vault.az_kv.id
  tenant_id               = data.azurerm_client_config.current.tenant_id
  object_id               = data.azurerm_client_config.current.object_id
  certificate_permissions = ["create", "get", "list", "import", "update", "delete"]
  secret_permissions      = ["get", "list", "set", "delete"]
}

