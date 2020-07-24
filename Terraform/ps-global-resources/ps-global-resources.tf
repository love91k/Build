

locals {
  common_tags = {
    ProductType    = "Trident"
    DeploymentDate = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    DeploymentBy   = var.deployed_by
    Environment    = var.subscription_identifier
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "global_rg" {
  name     = "rg-ps-shared-global"
  location = "eastus"
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_dns_zone" "global_domain" {
  name                = var.dns_name
  resource_group_name = azurerm_resource_group.global_rg.name
  tags                = local.common_tags
  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_security_center_subscription_pricing" "security_center" {
  count = var.subscription_identifier == "dev" ? 0 : 1
  tier  = "Standard"
}

resource "azurerm_shared_image_gallery" "global_sig" {
  name                = "sig${var.subscription_identifier}global"
  resource_group_name = azurerm_resource_group.global_rg.name
  location            = "eastus"
  description         = "PS SaaS images"
  tags                = local.common_tags
  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_shared_image" "pssaas_image" {
  name                = "pssaas_image"
  gallery_name        = "sig${var.subscription_identifier}global"
  resource_group_name = azurerm_resource_group.global_rg.name
  location            = "eastus"
  os_type             = "Windows"

  identifier {
    publisher = "beyondtrust"
    offer     = "trident"
    sku       = "trident"
  }
}