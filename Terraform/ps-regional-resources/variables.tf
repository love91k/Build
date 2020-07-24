variable "azure_region" {
  type = string
}

variable "deployment_data" {
  type = object({
    deployed_by             = string
    subscription_identifier = string
  })
  description = "Additional deployment data indicating the subscription and who deployed the resources"
}

variable "debug_postfix" {
  type    = string
  default = ""
}
