mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-test"
      output = { properties = { ipPrefix = "203.0.113.0/31" } }
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [
          {
            id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
            role_name = "Reader"
          }
        ]
      }
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

variables {
  location      = "norwayeast"
  name          = "ippre-test"
  parent_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  prefix_length = 31
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/publicIPPrefixes@2025-07-01" && azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The prefix should use the default resource type, name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.sku.name == "Standard" && azapi_resource.this.body.sku.tier == "Regional" && azapi_resource.this.body.properties.prefixLength == 31 && azapi_resource.this.body.properties.publicIPAddressVersion == "IPv4"
    error_message = "The defaults should be a Standard, Regional IPv4 prefix of the requested length."
  }
  assert {
    condition     = !contains(keys(azapi_resource.this.body), "zones") && !contains(keys(azapi_resource.this.body.properties), "customIPPrefix")
    error_message = "Zones and a custom prefix should be left out unless set."
  }
  assert {
    condition     = toset(azapi_resource.this.replace_triggers_refs) == toset(["sku.tier", "zones", "properties.prefixLength", "properties.publicIPAddressVersion", "properties.customIPPrefix"])
    error_message = "The properties Azure cannot change in place should replace the prefix, but not the SKU name."
  }
  assert {
    condition     = length(azapi_resource.lock) + length(time_sleep.lock_removal) + length(azapi_resource.role_assignments) + length(azapi_resource.diagnostic_settings) == 0
    error_message = "No lock, role assignment or diagnostic setting should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.ip_prefix == "203.0.113.0/31"
    error_message = "resource_id, name and ip_prefix should come from the prefix."
  }
}

run "prefix_options" {
  command = apply

  variables {
    sku_name            = "StandardV2"
    zones               = ["1", "2", "3"]
    ip_version          = "IPv6"
    prefix_length       = 124
    custom_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/customIPPrefixes/cip-test"
    tags                = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.body.sku.name == "StandardV2" && azapi_resource.this.body.zones == tolist(["1", "2", "3"]) && azapi_resource.this.body.properties.publicIPAddressVersion == "IPv6" && azapi_resource.this.body.properties.prefixLength == 124
    error_message = "sku_name, zones, ip_version and prefix_length should map to the request body."
  }
  assert {
    condition     = azapi_resource.this.body.properties.customIPPrefix.id == var.custom_ip_prefix_id && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "custom_ip_prefix_id and tags should be set."
  }
}

run "interfaces" {
  command = apply

  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "Reader"
        principal_id               = "55555555-5555-5555-5555-555555555555"
      }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        metrics               = [{ category = "AllMetrics" }]
      }
    }
    retry    = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts = { create = "15m" }
  }

  assert {
    condition     = azapi_resource.lock[0].parent_id == azapi_resource.this.id && time_sleep.lock_removal[0].triggers.public_ip_prefix_id == azapi_resource.this.id
    error_message = "The lock should be placed on the prefix, with a pause replaced with the prefix."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id && azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
    error_message = "Role assignments should be created on the prefix with resolved role definition IDs."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["workspace"].parent_id == azapi_resource.this.id && azapi_resource.diagnostic_settings["workspace"].name == "diag-workspace"
    error_message = "Diagnostic settings should be created on the prefix."
  }
  assert {
    condition     = alltrue([for r in [azapi_resource.this, azapi_resource.lock[0], azapi_resource.role_assignments["reader"], azapi_resource.diagnostic_settings["workspace"]] : r.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && r.timeouts.create == "15m"])
    error_message = "retry and timeouts should reach every resource."
  }
}

run "ipv4_prefix_too_long" {
  command = plan

  variables {
    prefix_length = 32
  }

  expect_failures = [var.prefix_length]
}

run "ipv4_prefix_too_short_without_custom_prefix" {
  command = plan

  variables {
    prefix_length = 27
  }

  expect_failures = [var.prefix_length]
}

run "ipv4_length_for_ipv6" {
  command = plan

  variables {
    ip_version    = "IPv6"
    prefix_length = 31
  }

  expect_failures = [var.prefix_length]
}

run "larger_prefix_from_custom_prefix" {
  command = plan

  variables {
    prefix_length       = 24
    custom_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/customIPPrefixes/cip-test"
  }

  assert {
    condition     = azapi_resource.this.body.properties.prefixLength == 24
    error_message = "A custom IP prefix should allow a larger prefix."
  }
}

run "invalid_custom_prefix_id" {
  command = plan

  variables {
    custom_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
  }

  expect_failures = [var.custom_ip_prefix_id]
}

run "global_tier_with_standard_v2" {
  command = plan

  variables {
    sku_tier = "Global"
    sku_name = "StandardV2"
  }

  expect_failures = [var.sku_tier]
}

run "invalid_zone" {
  command = plan

  variables {
    zones = ["0"]
  }

  expect_failures = [var.zones]
}
