output "key_vault" {
  value = azurerm_key_vault.az_kv
}

output "current_principal" {
  value = data.azurerm_client_config.current
}


