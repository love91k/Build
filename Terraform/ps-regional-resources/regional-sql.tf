locals {
  common_tags = {
    ProductType    = "Trident"
    DeploymentDate = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    DeploymentBy   = var.deployment_data.deployed_by
    Environment    = var.deployment_data.subscription_identifier
    SharedResource = true
  }

  dev_db_resources = {
    pool_capacity_gb    = 100,
    pool_capacity_dtu   = 100
    db_min_capacity_dtu = 20,
    db_max_capacity_dtu = 50,
    tier                = "standard"
  }

  #CN: Same for now until we sort out our needs
  prod_db_resources = {
    pool_capacity_gb    = 100,
    pool_capacity_dtu   = 100
    db_min_capacity_dtu = 20,
    db_max_capacity_dtu = 50,
    tier                = "standard"
  }

  db_resources = var.deployment_data.subscription_identifier == "dev" ? local.dev_db_resources : local.prod_db_resources

  regional_qualifier = "ps-${var.azure_region}${var.debug_postfix}"
  sql_admin          = "pssqladmin"
}



resource "azurerm_resource_group" "sql_rg" {
  name     = "rg-${local.regional_qualifier}-sql"
  location = var.azure_region
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "random_password" "sql_admin_password" {
  length           = 20
  lower            = true
  upper            = true
  number           = true
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!*+._~"
}

resource "azurerm_key_vault_secret" "sql_admin_pass" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "sqlAdminPass"
  value        = random_password.sql_admin_password.result
}

resource "azurerm_key_vault_secret" "sql_admin_user" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "sqlAdminUser"
  value        = local.sql_admin
}

resource "azurerm_storage_account" "sql_auditing" {
  name                      = "saps${var.debug_postfix}${var.deployment_data.subscription_identifier}sql"
  resource_group_name       = azurerm_resource_group.sql_rg.name
  location                  = azurerm_resource_group.sql_rg.location
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  account_tier              = "Standard"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_mssql_server" "regional_server" {
  name                          = "sql-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}"
  resource_group_name           = azurerm_resource_group.sql_rg.name
  location                      = azurerm_resource_group.sql_rg.location
  version                       = "12.0"
  administrator_login           = local.sql_admin
  administrator_login_password  = random_password.sql_admin_password.result
  public_network_access_enabled = false

  extended_auditing_policy {
    storage_endpoint           = azurerm_storage_account.sql_auditing.primary_blob_endpoint
    storage_account_access_key = azurerm_storage_account.sql_auditing.primary_access_key
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_mssql_elasticpool" "regional_epool" {
  name                = "epool-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}"
  resource_group_name = azurerm_resource_group.sql_rg.name
  location            = azurerm_resource_group.sql_rg.location
  server_name         = azurerm_mssql_server.regional_server.name
  max_size_gb         = local.db_resources.pool_capacity_gb

  tags = local.common_tags

  sku {
    name     = "StandardPool"
    tier     = local.db_resources.tier
    capacity = local.db_resources.pool_capacity_dtu
  }

  per_database_settings {
    min_capacity = local.db_resources.db_min_capacity_dtu
    max_capacity = local.db_resources.db_max_capacity_dtu
  }

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
  #TODO:CN -- LicenseType?
}

resource "azurerm_virtual_network" "regional_sql_vnet" {
  name                = "vnet-sql-${local.regional_qualifier}"
  location            = azurerm_resource_group.sql_rg.location
  resource_group_name = azurerm_resource_group.sql_rg.name
  address_space       = ["10.0.0.0/26"]
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_subnet" "sql_endpoint_subnet" {
  name                                           = "snet-sql-${local.regional_qualifier}"
  resource_group_name                            = azurerm_resource_group.sql_rg.name
  virtual_network_name                           = azurerm_virtual_network.regional_sql_vnet.name
  address_prefixes                               = ["10.0.0.0/26"]
  enforce_private_link_endpoint_network_policies = true
}


resource "azurerm_private_endpoint" "sql_private_endpoint" {
  name                = "pe-sql-${local.regional_qualifier}"
  location            = azurerm_resource_group.sql_rg.location
  resource_group_name = azurerm_resource_group.sql_rg.name
  subnet_id           = azurerm_subnet.sql_endpoint_subnet.id
  private_service_connection {
    name                           = "sql_private_connection"
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
    private_connection_resource_id = azurerm_mssql_server.regional_server.id
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}
