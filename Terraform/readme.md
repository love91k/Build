# Deploying a Cluster with Terraform

## Important notes

- The terraform state file doesn't do any magic with secrets so **DO NOT** use the local storage backend for prod clusters (Use the azurerm backend that is partially configured/the yml pipeline)

## Prerequisites

- Download and install az CLI [Microsoft](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest)
- Download and install Terraform [Hashicorp](https://www.hashicorp.com/products/terraform)
- Ensure that you have a storage account in Azure to store state in and get the access key [Microsoft](https://docs.microsoft.com/en-us/azure/terraform/terraform-backend)
- Create a service principal that can access the subscription that you're acting on and the state storage - You may have to talk to IT/Systems team for this[Terraform Docs](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html)

## Getting started

1. Open up a terminal in this directory. You can run the cluster provision in `powershell` or `make` to prevent typing out the terraform workflow. You can install [Gnu make](http://gnuwin32.sourceforge.net/packages/make.htm) build utility via [chocolatey](https://chocolatey.org/) `choco install make -y`

2. If you **do not** have a service principal's credentials available to you you will have to have one made for you.
3. This **WILL NOT WORK** without using a service principal as it authorizes the current principal on the Key Vaults
4. Set the following environment variables:

```ps
$env:ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000" #(App Id)
$env:ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000" #(Password)
$env:ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000" #(Subscription)
$env:ARM_TENANT_ID="00000000-0000-0000-0000-000000000000" #(Tenant)
$env:ARM_ACCESS_KEY="00000000-0000-0000-0000-000000000000" #(Required for configuring a remote backend in azure blob storage)
```

5. Generate terraform config with the required certificates:
    * `.\tfConfig.ps1 -azureRegion northeurope -deployedBy <yourName>` or
    * `make config`
6. Run terraform init:
    * `terraform init --backend_config="resource_group_name=storageaccount-resource-group"--backend-config="storage_account_name=storageaccount" --backend-config="container_name=blobcontainertostorestate" --backend-config="key=specific_state_file_name"` or 
    * `make tfinit BACKEND_STORAGE_ACCOUNT=<storage_account> BACKEND_CONTAINER=<container>`
7. Generate the execution plan: 
    * `terraform plan -var-file=vars.auto.tfvars.json -out cluster.tfplan` or
    * `make tfplan`
8. Inspect the plan that is generated
9. Execute the plan: 
    * `terraform apply "cluster.tfplan"` or
    * `make tfapply`

That's it! Terraform should take care of the rest.

## Deprovisioning

1. Make sure your backend state is pointing to the right place (storage account, container and file)
2. Run:
    * `terraform destroy -var-file=vars.auto.tfvars.json` or
    * `make tfdestroy`
3. Read the execution plan and make sure the names line up
4. type yes!
