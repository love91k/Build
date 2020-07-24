# Azure Key Vault with pre-configured Service Principal access policy

The default workflow for provisioning a keyvault is to create it and set permission to create and edit certificates and secrets on the current service principal. This ends up being a lot of boiler plate. This combines both of those into a single, simpler resource.

This may not meet your needs if you need to do additional customization but for most default configured keyvaults this is reliable.

## Requirements

- Service principal authentication to azure

## Outputs

- Outputs the keyvault resource [DOCS](https://www.terraform.io/docs/providers/azurerm/r/key_vault.html) as the attribute key_vault.
