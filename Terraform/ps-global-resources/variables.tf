variable "azure_region" {
  type = string
}

variable "dns_name" {
  type = string
}

variable "subscription_identifier" {
  type = string
}

variable "deployed_by" {
  type = string
}

variable "certificate" {
  type = object({
    path     = string
    password = string
    size     = number
    type     = string
  })
}

variable "debug_postfix" {
  type    = string
  default = ""
}
