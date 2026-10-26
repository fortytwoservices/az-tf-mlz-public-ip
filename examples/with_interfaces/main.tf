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
  tags     = { example = "with_interfaces" }
}

resource "azapi_resource" "log_analytics_workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  name      = "log-mlz-pip-${random_string.suffix.result}"
  parent_id = azapi_resource.resource_group.id
  location  = local.location
  body = {
    properties = {
      retentionInDays = 30
      sku             = { name = "PerGB2018" }
    }
  }

  response_export_values = []
  tags                   = local.tags
}

module "public_ip" {
  source = "../../"

  name              = "pip-mlz-${random_string.suffix.result}"
  parent_id         = azapi_resource.resource_group.id
  location          = local.location
  zones             = ["1", "2", "3"]
  domain_name_label = "pip-mlz-${random_string.suffix.result}"
  diagnostic_settings = {
    workspace = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      logs                  = [{ category_group = "allLogs" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  lock = {
    kind = "CanNotDelete"
  }
  role_assignments = {
    deployer_reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azapi_client_config.current.object_id
    }
  }
  tags = local.tags
}

module "public_ip_prefix" {
  source = "../../modules/public_ip_prefix"

  name          = "ippre-mlz-${random_string.suffix.result}"
  parent_id     = azapi_resource.resource_group.id
  location      = local.location
  prefix_length = 31
  diagnostic_settings = {
    workspace = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      logs                  = [{ category = "DDoSProtectionNotifications" }]
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  lock = {
    kind = "CanNotDelete"
  }
  tags = local.tags
}
