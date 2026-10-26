# Subscription from ARM_SUBSCRIPTION_ID or the Azure CLI; credentials from the Azure CLI or OIDC.
provider "azapi" {}

data "azapi_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-11-01"
  name      = "rg-mlz-pip-${random_string.suffix.result}"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = local.location

  response_export_values = []
  tags                   = local.tags
}

locals {
  location = "norwayeast"
  tags     = { example = "prefix" }
}

module "public_ip_prefix" {
  source = "../../modules/public_ip_prefix"

  name          = "ippre-mlz-${random_string.suffix.result}"
  parent_id     = azapi_resource.resource_group.id
  location      = local.location
  prefix_length = 31 # two addresses
  tags          = local.tags
}

module "public_ip" {
  source   = "../../"
  for_each = toset(["1", "2"])

  name                = "pip-mlz-${random_string.suffix.result}-${each.key}"
  parent_id           = azapi_resource.resource_group.id
  location            = local.location
  public_ip_prefix_id = module.public_ip_prefix.resource_id
  tags                = local.tags
}
