module "key_vault" {
  source = "../modules/current-principal-keyvault"

  name                     = "kv-ps-${var.subscription_identifier}-global"
  resource_group_name      = azurerm_resource_group.global_rg.name
  location                 = azurerm_resource_group.global_rg.location
  soft_delete_enabled      = var.subscription_identifier != "dev"
  purge_protection_enabled = var.subscription_identifier != "dev"
  sku_name                 = "standard"
  tags                     = local.common_tags
}

resource "azurerm_key_vault_certificate" "wildcard_tls" {
  name         = "ps-wildcard-tls"
  key_vault_id = module.key_vault.key_vault.id
  depends_on   = [module.key_vault]

  certificate {
    contents = file(var.certificate.path)
    password = var.certificate.password
  }

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = var.certificate.size
      key_type   = var.certificate.type
      reuse_key  = false
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }
  }
}
