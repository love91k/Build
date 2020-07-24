variable "name" {
  type        = string
  description = "The name of the keyvault to provision"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group to deploy the Key Vault into"
}

variable "location" {
  type        = string
  description = "the location to deploy the keyvault"
}

variable "soft_delete_enabled" {
  type        = bool
  description = "Should the keys and the keyvault be soft deleted?"
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Should purge protection be enabled for the keyvault? Beware this limits the ability to delete"
}

variable "sku_name" {
  type        = string
  default     = "standard"
  description = "The sku of the keyvault [standard, premium]"
}

variable "tags" {
  type = object({
    ProductType    = string
    DeploymentDate = string
    DeploymentBy   = string
    Environment    = string
  })
}
