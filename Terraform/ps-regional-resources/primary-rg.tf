data "azurerm_client_config" "current" {}

locals {
  dev_app_insights_settings = {
    retention_days      = 30
    daily_data_cap_gb   = 1
    sampling_percentage = 100
  }

  prod_app_insights_settings = {
    retention_days      = 90
    daily_data_cap_gb   = 10
    sampling_percentage = 1
  }

  dev_log_analytics_settings = {
    sku            = "Free"
    retention_days = 7
  }

  prod_log_analytics_settings = {
    sku            = "PerGB2018"
    retention_days = 30
  }

  app_insight_settings   = var.deployment_data.subscription_identifier == "dev" ? local.dev_app_insights_settings : local.prod_app_insights_settings
  log_analytics_settings = var.deployment_data.subscription_identifier == "dev" ? local.dev_log_analytics_settings : local.prod_log_analytics_settings
}


resource "azurerm_resource_group" "regional_rg" {
  name     = "rg-${local.regional_qualifier}"
  location = var.azure_region
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

module "key_vault" {
  source = "../modules/current-principal-keyvault"

  name                     = "kv-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}"
  resource_group_name      = azurerm_resource_group.regional_rg.name
  location                 = azurerm_resource_group.regional_rg.location
  soft_delete_enabled      = var.deployment_data.subscription_identifier != "dev"
  purge_protection_enabled = var.deployment_data.subscription_identifier != "dev"
  sku_name                 = "standard"
  tags                     = local.common_tags
}

resource "azurerm_application_insights" "shared_app_insights" {
  name                = "ai-${local.regional_qualifier}"
  resource_group_name = azurerm_resource_group.regional_rg.name
  location            = azurerm_resource_group.regional_rg.location
  application_type    = "web"

  daily_data_cap_in_gb = local.app_insight_settings.daily_data_cap_gb
  retention_in_days    = local.app_insight_settings.retention_days
  sampling_percentage  = local.app_insight_settings.sampling_percentage

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_log_analytics_workspace" "regional_workspace" {
  name                = "la-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}-trident"
  resource_group_name = azurerm_resource_group.regional_rg.name
  location            = azurerm_resource_group.regional_rg.location
  sku                 = local.log_analytics_settings.sku
  retention_in_days   = local.log_analytics_settings.retention_days

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}


resource "azurerm_key_vault_secret" "app_insights_key" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "app-insights-key"
  value        = azurerm_application_insights.shared_app_insights.instrumentation_key
}

resource "azurerm_key_vault_secret" "log_analytics_key" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "log-analytics-key"
  value        = azurerm_log_analytics_workspace.regional_workspace.primary_shared_key
}



