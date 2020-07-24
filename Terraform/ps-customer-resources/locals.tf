locals {
  common_tags = {
    ProductType    = "Trident"
    DeploymentDate = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    DeploymentBy   = var.deployment_data.deployed_by
    Environment    = var.deployment_data.subscription_identifier
  }

  cust_qualifier     = "ps-${var.customer_name}${var.debug_postfix}"
  regional_qualifier = "ps-${var.azure_region}${var.debug_postfix}"

  #Same for now until we have a spec
  dev_db_settings = {
    max_size_gb             = 10,
    auditing_retention_days = 7

  }

  prod_db_settings = {
    max_size_gb             = null,
    auditing_retention_days = 7
  }

  sql_db_settings = var.deployment_data.subscription_identifier == "dev" ? local.dev_db_settings : local.prod_db_settings

  frontend_ip_config_name = "PublicIPAddress"
  scaleset_admin_username = "psAdmin"
}
