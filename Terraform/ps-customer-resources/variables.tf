variable "customer_name" {
  type = string
}

variable "azure_region" {
  type = string
}

variable "deployment_data" {
  type = object({
    deployed_by             = string
    subscription_identifier = string
  })
}

variable "debug_postfix" {
  type    = string
  default = ""
}

variable "vnet_address_space" {
  type = list
}
