data "azurerm_resource_group" "regional_rg" {
  name = "rg-${local.regional_qualifier}"
}

data "azurerm_resource_group" "sql_rg" {
  name = "rg-${local.regional_qualifier}-sql"
}

data "azurerm_virtual_network" "sql_vnet" {
  name                = "vnet-sql-${local.regional_qualifier}"
  resource_group_name = data.azurerm_resource_group.sql_rg.name
}

data "azurerm_sql_server" "regional_sql_server" {
  name                = "sql-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}"
  resource_group_name = data.azurerm_resource_group.sql_rg.name
}

data "azurerm_storage_account" "sql_auditing" {
  name                = "saps${var.debug_postfix}${var.deployment_data.subscription_identifier}sql"
  resource_group_name = data.azurerm_resource_group.sql_rg.name
}

data "azurerm_mssql_elasticpool" "regional_pool" {
  name                = "epool-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}"
  resource_group_name = data.azurerm_resource_group.sql_rg.name
  server_name         = data.azurerm_sql_server.regional_sql_server.name
}

data "azurerm_log_analytics_workspace" "regional_la_workspace" {
  name                = "la-${local.regional_qualifier}-${var.deployment_data.subscription_identifier}-trident"
  resource_group_name = data.azurerm_resource_group.regional_rg.name
}

data "azurerm_application_insights" "regional_ai" {
  name                = "ai-${local.regional_qualifier}"
  resource_group_name = data.azurerm_resource_group.regional_rg.name
}

resource "random_password" "scaleset_admin_password" {
  length           = 20
  lower            = true
  upper            = true
  number           = true
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!*+.:_~"
}

resource "random_password" "sql_user_password" {
  length           = 20
  lower            = true
  upper            = true
  number           = true
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!*+.:_~"
}

resource "azurerm_mssql_database" "customer_db" {
  name                        = "sqldb-${local.cust_qualifier}"
  server_id                   = data.azurerm_sql_server.regional_sql_server.id
  elastic_pool_id             = data.azurerm_mssql_elasticpool.regional_pool.id
  collation                   = "SQL_Latin1_General_CP1_CI_AS"
  max_size_gb                 = local.sql_db_settings.max_size_gb
  create_mode                 = "Copy"
  creation_source_database_id = "/subscriptions/a471a178-3fda-47fc-a632-751f4cbf71c3/resourceGroups/uvm-eus-egg-rg/providers/Microsoft.Sql/servers/uvm-eus-egg-sqldb/databases/BeyondInsight-6-10-blank"

  extended_auditing_policy {
    storage_endpoint           = data.azurerm_storage_account.sql_auditing.primary_blob_endpoint
    storage_account_access_key = data.azurerm_storage_account.sql_auditing.primary_access_key
    retention_in_days          = local.sql_db_settings.auditing_retention_days
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_resource_group" "customer_rg" {
  name     = "rg-ps-${var.customer_name}${var.debug_postfix}"
  location = var.azure_region
}

resource "azurerm_virtual_network" "customer_vnet" {
  name                = "vnet-${local.cust_qualifier}"
  location            = azurerm_resource_group.customer_rg.location
  resource_group_name = azurerm_resource_group.customer_rg.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_subnet" "customer_subnet" {
  name                                           = "snet-${local.cust_qualifier}"
  resource_group_name                            = azurerm_resource_group.customer_rg.name
  virtual_network_name                           = azurerm_virtual_network.customer_vnet.name
  address_prefixes                               = var.vnet_address_space
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_public_ip" "pub_ip" {
  name                = "ip-${local.cust_qualifier}"
  resource_group_name = azurerm_resource_group.customer_rg.name
  location            = azurerm_resource_group.customer_rg.location

  sku                     = "Standard"
  ip_version              = "IPv4"
  domain_name_label       = var.customer_name
  allocation_method       = "Static"
  idle_timeout_in_minutes = 5
}

resource "azurerm_lb" "main_lb" {
  name                = "lb-${local.cust_qualifier}"
  resource_group_name = azurerm_resource_group.customer_rg.name
  location            = azurerm_resource_group.customer_rg.location
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = local.frontend_ip_config_name
    public_ip_address_id          = azurerm_public_ip.pub_ip.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_lb_rule" "lb_tls_rule" {
  name                = "lb-tls-443-rule"
  resource_group_name = azurerm_resource_group.customer_rg.name
  loadbalancer_id     = azurerm_lb.main_lb.id

  protocol                       = "TCP"
  load_distribution              = "SourceIPProtocol"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.scaleset_backend_pool.id
  frontend_ip_configuration_name = local.frontend_ip_config_name
  frontend_port                  = 443
  backend_port                   = 443
  idle_timeout_in_minutes        = 5
  enable_floating_ip             = false
  probe_id                       = azurerm_lb_probe.tls_probe.id
}

resource "azurerm_lb_probe" "tls_probe" {
  depends_on          = [azurerm_lb_backend_address_pool.scaleset_backend_pool]
  name                = "TlsProbe"
  resource_group_name = azurerm_resource_group.customer_rg.name

  loadbalancer_id     = azurerm_lb.main_lb.id
  protocol            = "TCP"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_rule" "lb_http_rule" {
  name                = "lb-tls-80-rule"
  resource_group_name = azurerm_resource_group.customer_rg.name
  loadbalancer_id     = azurerm_lb.main_lb.id

  protocol                       = "TCP"
  load_distribution              = "SourceIPProtocol"
  backend_address_pool_id        = azurerm_lb_backend_address_pool.scaleset_backend_pool.id
  frontend_ip_configuration_name = local.frontend_ip_config_name
  frontend_port                  = 80
  backend_port                   = 80
  idle_timeout_in_minutes        = 5
  enable_floating_ip             = false
  probe_id                       = azurerm_lb_probe.http_probe.id
}

resource "azurerm_lb_probe" "http_probe" {
  depends_on          = [azurerm_lb_backend_address_pool.scaleset_backend_pool]
  name                = "httpProbe"
  resource_group_name = azurerm_resource_group.customer_rg.name

  loadbalancer_id     = azurerm_lb.main_lb.id
  protocol            = "TCP"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_network_security_group" "customer_nsg" {
  name                = "nsg-${local.cust_qualifier}"
  resource_group_name = azurerm_resource_group.customer_rg.name
  location            = azurerm_resource_group.customer_rg.location
}

resource "azurerm_subnet_network_security_group_association" "subnet_assoc" {
  subnet_id                 = azurerm_subnet.customer_subnet.id
  network_security_group_id = azurerm_network_security_group.customer_nsg.id
}

resource "azurerm_network_security_rule" "http_nsg_rule" {
  name                        = "http-nsg-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.customer_rg.name
  network_security_group_name = azurerm_network_security_group.customer_nsg.name
}

resource "azurerm_network_security_rule" "https_nsg_rule" {
  name                        = "https-nsg-rule"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.customer_rg.name
  network_security_group_name = azurerm_network_security_group.customer_nsg.name
}

resource "azurerm_virtual_network_peering" "customer_to_sql_peering" {
  name                         = "${var.customer_name}-peering-to-sql-vnet"
  resource_group_name          = azurerm_resource_group.customer_rg.name
  virtual_network_name         = azurerm_virtual_network.customer_vnet.name
  remote_virtual_network_id    = data.azurerm_virtual_network.sql_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = false
}

resource "azurerm_virtual_network_peering" "sql_to_compute_peering" {
  name                         = "sql-vnet-peering-to-${var.customer_name}"
  resource_group_name          = data.azurerm_resource_group.sql_rg.name
  virtual_network_name         = data.azurerm_virtual_network.sql_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.customer_vnet.id
  allow_virtual_network_access = false
  allow_forwarded_traffic      = false
}

resource "azurerm_resource_group" "cust_kv_rg" {
  name     = "rg-kv-${local.cust_qualifier}"
  location = var.azure_region
  tags     = local.common_tags

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

module "key_vault" {
  source = "../modules/current-principal-keyvault"

  name                     = "kv-${local.cust_qualifier}"
  resource_group_name      = azurerm_resource_group.cust_kv_rg.name
  location                 = azurerm_resource_group.cust_kv_rg.location
  soft_delete_enabled      = var.deployment_data.subscription_identifier != "dev"
  purge_protection_enabled = var.deployment_data.subscription_identifier != "dev"
  sku_name                 = "standard"
  tags                     = local.common_tags
}

resource "azurerm_key_vault_secret" "log_analyics_key" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "log-analytics-key"
  value        = data.azurerm_log_analytics_workspace.regional_la_workspace.secondary_shared_key
}

resource "azurerm_key_vault_secret" "log_analyics_ws_id" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "log-analytics-workspace-id"
  value        = data.azurerm_log_analytics_workspace.regional_la_workspace.workspace_id
}

resource "azurerm_key_vault_secret" "app_insights_key" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "app-insights-key"
  value        = data.azurerm_application_insights.regional_ai.instrumentation_key
}

resource "azurerm_key_vault_secret" "bi_scaleset_pass" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "ps-scalesetadmin-password"
  value        = random_password.scaleset_admin_password.result
}

resource "azurerm_key_vault_secret" "bi_scaleset_user" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "ps-scalesetadmin-username"
  value        = local.scaleset_admin_username
}

resource "azurerm_lb_backend_address_pool" "scaleset_backend_pool" {
  name                = "LoadBalancerBEAddressPool"
  resource_group_name = azurerm_resource_group.customer_rg.name
  loadbalancer_id     = azurerm_lb.main_lb.id
}

resource "azurerm_key_vault_secret" "bi_sql_pass" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "ps-sqluser-password"
  value        = random_password.sql_user_password.result
}

resource "azurerm_key_vault_secret" "bi_sql_user" {
  depends_on   = [module.key_vault]
  key_vault_id = module.key_vault.key_vault.id
  name         = "ps-sqluser-username"
  value        = "sqluser-${local.cust_qualifier}"
}

resource "azurerm_windows_virtual_machine_scale_set" "nodes" {
  depends_on           = [azurerm_lb_rule.lb_tls_rule]
  name                 = "${var.customer_name}-vmss"
  resource_group_name  = azurerm_resource_group.customer_rg.name
  location             = azurerm_resource_group.customer_rg.location
  instances            = 2
  sku                  = "Standard_D2_v3"
  license_type         = var.deployment_data.subscription_identifier != "dev" ? "Windows_Server" : null
  overprovision        = false
  health_probe_id      = azurerm_lb_probe.tls_probe.id
  computer_name_prefix = var.customer_name

  admin_username = local.scaleset_admin_username
  admin_password = random_password.scaleset_admin_password.result
  tags           = local.common_tags


  identity {
    type = "SystemAssigned"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadOnly"
  }

  data_disk {
    caching                   = "None"
    create_option             = "FromImage"
    disk_size_gb              = 1023
    lun                       = 0
    storage_account_type      = "Standard_LRS"
    write_accelerator_enabled = false
  }

  source_image_reference {
    publisher = "beyondtrust"
    offer     = "beyondinsight"
    sku       = "uvm-azm"
    version   = "latest"
  }

  plan {
    name      = "uvm-azm"
    product   = "beyondinsight"
    publisher = "beyondtrust"
  }

  network_interface {
    name    = "${var.customer_name}-clusternic"
    primary = true
    ip_configuration {
      name                                   = "${var.customer_name}-clusternic"
      primary                                = true
      subnet_id                              = azurerm_subnet.customer_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.scaleset_backend_pool.id]
    }
  }

  lifecycle {
    ignore_changes = [tags["DeploymentDate"]]
  }
}

resource "azurerm_key_vault_access_policy" "vmss_access_permissions" {
  key_vault_id = module.key_vault.key_vault.id
  tenant_id    = module.key_vault.current_principal.tenant_id
  object_id    = azurerm_windows_virtual_machine_scale_set.nodes.identity[0].principal_id

  secret_permissions = ["get"]
}

resource "azurerm_relay_namespace" "customer_relay" {
  name                = "relay-${local.cust_qualifier}"
  location            = azurerm_resource_group.customer_rg.location
  resource_group_name = azurerm_resource_group.customer_rg.name

  sku_name = "Standard"
}

resource "azurerm_relay_hybrid_connection" "defaultzone" {
  name                 = "defaultzone"
  resource_group_name  = azurerm_resource_group.customer_rg.name
  relay_namespace_name = azurerm_relay_namespace.customer_relay.name
  user_metadata        = "defaultzonedata"
}

resource "azurerm_relay_hybrid_connection" "upstream" {
  name                 = "upstream"
  resource_group_name  = azurerm_resource_group.customer_rg.name
  relay_namespace_name = azurerm_relay_namespace.customer_relay.name
  user_metadata        = "upstreamdata"
}