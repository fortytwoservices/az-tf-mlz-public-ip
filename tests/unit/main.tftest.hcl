mock_provider "azapi" {
  mock_resource "azapi_resource" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-test"
      output = {
        properties = {
          ipAddress   = "203.0.113.10"
          dnsSettings = { fqdn = "pip-test.norwayeast.cloudapp.azure.com" }
        }
      }
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
  location  = "norwayeast"
  name      = "pip-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test"
}

run "defaults" {
  command = apply

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/publicIPAddresses@2025-07-01"
    error_message = "The public IP address should use the default resource type."
  }
  assert {
    condition     = azapi_resource.this.name == var.name && azapi_resource.this.parent_id == var.parent_id && azapi_resource.this.location == var.location
    error_message = "The public IP address should be created with name, parent_id and location."
  }
  assert {
    condition     = azapi_resource.this.body.sku.name == "Standard" && azapi_resource.this.body.sku.tier == "Regional"
    error_message = "The default SKU should be Standard, Regional."
  }
  assert {
    condition     = azapi_resource.this.body.properties.publicIPAllocationMethod == "Static" && azapi_resource.this.body.properties.publicIPAddressVersion == "IPv4" && azapi_resource.this.body.properties.idleTimeoutInMinutes == 4
    error_message = "The defaults should be a static IPv4 address with a 4-minute idle timeout."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.ipTags) == 0
    error_message = "No IP tags should be sent by default."
  }
  assert {
    condition     = !contains(keys(azapi_resource.this.body), "zones")
    error_message = "Zones should be left out unless set, so Azure's zone default is not compared."
  }
  assert {
    condition     = alltrue([for key in ["dnsSettings", "publicIPPrefix"] : contains(keys(azapi_resource.this.body.properties), key) && azapi_resource.this.body.properties[key] == null])
    error_message = "Without a label and a prefix, dnsSettings and publicIPPrefix should be sent as null, so that removing them later clears them."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ddosSettings.protectionMode == "VirtualNetworkInherited" && azapi_resource.this.body.properties.ddosSettings.ddosProtectionPlan == null
    error_message = "The DDoS settings should default to Azure's VirtualNetworkInherited mode, sent explicitly."
  }
  assert {
    condition     = toset(azapi_resource.this.replace_triggers_refs) == toset(["sku", "properties.publicIPAddressVersion", "properties.ipTags"])
    error_message = "The always-set properties Azure cannot change in place should replace the address."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.domain_name_label_scope == null && azapi_resource.this.replace_triggers_external_values.public_ip_prefix_id == null && azapi_resource.this.replace_triggers_external_values.zones == null
    error_message = "The nullable properties Azure cannot change in place should be compared as inputs."
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && length(coalesce(azapi_resource.this.tags, {})) == 0
    error_message = "retry, timeouts and tags should be unset by default."
  }
  assert {
    condition     = length(azapi_resource.lock) + length(time_sleep.lock_removal) + length(azapi_resource.role_assignments) + length(azapi_resource.diagnostic_settings) == 0
    error_message = "No lock, role assignment or diagnostic setting should be created by default."
  }
  assert {
    condition     = output.resource_id == azapi_resource.this.id && output.name == var.name && output.ip_address == "203.0.113.10"
    error_message = "resource_id, name and ip_address should come from the public IP address."
  }
}

run "address_options" {
  command = apply

  variables {
    zones                   = ["3", "1", "2", "1"]
    idle_timeout_in_minutes = 30
    ip_tags                 = { RoutingPreference = "Internet" }
    public_ip_prefix_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPPrefixes/ippre-test"
    domain_name_label       = "pip-test"
    domain_name_label_scope = "TenantReuse"
    reverse_fqdn            = "www.example.com."
    tags                    = { environment = "test" }
  }

  assert {
    condition     = azapi_resource.this.body.zones == tolist(["1", "2", "3"]) && azapi_resource.this.body.properties.idleTimeoutInMinutes == 30
    error_message = "zones (sorted, de-duplicated) and idle_timeout_in_minutes should map to the request body."
  }
  assert {
    condition     = azapi_resource.this.body.properties.ipTags[0].ipTagType == "RoutingPreference" && azapi_resource.this.body.properties.ipTags[0].tag == "Internet"
    error_message = "ip_tags should map to ipTags entries."
  }
  assert {
    condition     = azapi_resource.this.body.properties.publicIPPrefix.id == var.public_ip_prefix_id
    error_message = "public_ip_prefix_id should map to properties.publicIPPrefix."
  }
  assert {
    condition     = azapi_resource.this.body.properties.dnsSettings.domainNameLabel == "pip-test" && azapi_resource.this.body.properties.dnsSettings.domainNameLabelScope == "TenantReuse" && azapi_resource.this.body.properties.dnsSettings.reverseFqdn == "www.example.com."
    error_message = "The DNS inputs should map to properties.dnsSettings."
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_external_values.domain_name_label_scope == "TenantReuse" && azapi_resource.this.replace_triggers_external_values.public_ip_prefix_id == var.public_ip_prefix_id && azapi_resource.this.replace_triggers_external_values.zones == tolist(["1", "2", "3"])
    error_message = "The replacement inputs should hold the sorted zones, the prefix and the label scope."
  }
  assert {
    condition     = output.fqdn == "pip-test.norwayeast.cloudapp.azure.com" && azapi_resource.this.tags == tomap({ environment = "test" })
    error_message = "fqdn should come from the exported DNS settings, and tags should be set."
  }
}

run "standard_v2_ipv6" {
  command = apply

  variables {
    sku_name   = "StandardV2"
    ip_version = "IPv6"
    zones      = ["1", "2", "3"]
  }

  assert {
    condition     = azapi_resource.this.body.sku.name == "StandardV2" && azapi_resource.this.body.properties.publicIPAddressVersion == "IPv6"
    error_message = "sku_name and ip_version should map to the request body."
  }
}

run "dns_label_only" {
  command = apply

  variables {
    domain_name_label = "pip-test"
  }

  assert {
    condition     = azapi_resource.this.body.properties.dnsSettings.domainNameLabel == "pip-test" && azapi_resource.this.body.properties.dnsSettings.domainNameLabelScope == null && azapi_resource.this.body.properties.dnsSettings.reverseFqdn == null
    error_message = "Unset DNS inputs should be sent as nulls in properties.dnsSettings."
  }
}

run "ddos_protection" {
  command = apply

  variables {
    ddos_protection_mode    = "Enabled"
    ddos_protection_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
  }

  assert {
    condition     = azapi_resource.this.body.properties.ddosSettings.protectionMode == "Enabled" && azapi_resource.this.body.properties.ddosSettings.ddosProtectionPlan.id == var.ddos_protection_plan_id
    error_message = "The DDoS inputs should map to properties.ddosSettings."
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
      tenant_level_id = {
        role_definition_id_or_name       = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                     = "66666666-6666-6666-6666-666666666666"
        skip_service_principal_aad_check = true
        description                      = "Read the address."
      }
    }
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
      named = {
        name                  = "diag-custom"
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
        logs                  = [{ category = "DDoSProtectionNotifications" }]
      }
    }
  }

  assert {
    condition     = azapi_resource.lock[0].name == "lock-CanNotDelete" && azapi_resource.lock[0].parent_id == azapi_resource.this.id && azapi_resource.lock[0].body.properties.level == "CanNotDelete"
    error_message = "The lock should be placed on the public IP address."
  }
  assert {
    condition     = time_sleep.lock_removal[0].destroy_duration == "30s" && time_sleep.lock_removal[0].triggers.public_ip_address_id == azapi_resource.this.id
    error_message = "A lock should come with the 30s removal pause, replaced with the address."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" && azapi_resource.role_assignments["reader"].parent_id == azapi_resource.this.id
    error_message = "A role name should resolve to its role definition ID, on the public IP address."
  }
  assert {
    condition     = azapi_resource.role_assignments["tenant_level_id"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7" && azapi_resource.role_assignments["tenant_level_id"].body.properties.principalType == "ServicePrincipal"
    error_message = "A tenant-level role definition ID should be qualified with the subscription, and the skip flag should set principalType."
  }
  assert {
    condition     = time_sleep.lock_removal[0].triggers.children == sha256(jsonencode([var.diagnostic_settings, var.role_assignments]))
    error_message = "A change to the diagnostic settings or role assignments should replace the pause, and with it the lock."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["workspace"].replace_triggers_external_values.workspace_resource_id == var.diagnostic_settings["workspace"].workspace_resource_id
    error_message = "Any change to a diagnostic setting's inputs should recreate it."
  }
  assert {
    condition     = azapi_resource.role_assignments["tenant_level_id"].replace_triggers_external_values.description == "Read the address." && azapi_resource.role_assignments["reader"].replace_triggers_external_values.description == null && azapi_resource.role_assignments["reader"].replace_triggers_external_values.condition == null
    error_message = "A role assignment's description and condition should be replacement inputs, so clearing them reaches Azure."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["workspace"].name == "diag-workspace" && azapi_resource.diagnostic_settings["named"].name == "diag-custom"
    error_message = "Diagnostic settings should be named diag-<key> unless a name is given."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["workspace"].parent_id == azapi_resource.this.id && azapi_resource.diagnostic_settings["workspace"].type == "Microsoft.Insights/diagnosticSettings@2021-05-01-preview"
    error_message = "Diagnostic settings should be created on the public IP address with the default resource type."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["workspace"].body.properties.workspaceId == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test" && azapi_resource.diagnostic_settings["workspace"].body.properties.logs[0].categoryGroup == "allLogs" && azapi_resource.diagnostic_settings["workspace"].body.properties.metrics[0].category == "AllMetrics"
    error_message = "The diagnostic setting should send the requested logs and metrics to the workspace."
  }
}

run "azapi_settings_reach_every_resource" {
  command = apply

  # ignore_body_changes is write-only, so a test cannot read it back; setting it proves the slots are
  # accepted. Which resource reads which slot is left to review.
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
    resource_types = {
      network_public_ip_addresses    = "Microsoft.Network/publicIPAddresses@2024-10-01"
      authorization_locks            = "Microsoft.Authorization/locks@2016-09-01"
      authorization_role_assignments = "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
      # No other diagnostic settings API version has this body's shape (2020-01-01-preview has no
      # metrics), so the insights_diagnostic_settings slot is not overridden here.
    }
    ignore_body_changes = {
      network_public_ip_addresses    = ["properties.idleTimeoutInMinutes"]
      authorization_locks            = ["properties.notes"]
      authorization_role_assignments = ["properties.description"]
      insights_diagnostic_settings   = ["properties.logs"]
    }
    retry    = { error_message_regex = ["AnotherOperationInProgress"] }
    timeouts = { create = "15m" }
  }

  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/publicIPAddresses@2024-10-01" && azapi_resource.lock[0].type == "Microsoft.Authorization/locks@2016-09-01" && azapi_resource.role_assignments["reader"].type == "Microsoft.Authorization/roleAssignments@2020-04-01-preview"
    error_message = "resource_types overrides should reach the address, the lock and the role assignments."
  }
  assert {
    condition     = alltrue([for r in [azapi_resource.this, azapi_resource.lock[0], azapi_resource.role_assignments["reader"], azapi_resource.diagnostic_settings["workspace"]] : r.retry.error_message_regex == tolist(["AnotherOperationInProgress"]) && r.timeouts.create == "15m"])
    error_message = "retry and timeouts should reach every resource."
  }
}

run "invalid_name" {
  command = plan

  variables {
    name = "-pip"
  }

  expect_failures = [var.name]
}

run "invalid_parent_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [var.parent_id]
}

run "basic_sku" {
  command = plan

  variables {
    sku_name = "Basic"
  }

  expect_failures = [var.sku_name]
}

run "global_tier_with_zones" {
  command = plan

  variables {
    sku_tier = "Global"
    zones    = ["1"]
  }

  expect_failures = [var.sku_tier]
}

run "invalid_zone" {
  command = plan

  variables {
    zones = ["4"]
  }

  expect_failures = [var.zones]
}

run "empty_zones" {
  command = plan

  variables {
    zones = []
  }

  expect_failures = [var.zones]
}

run "zonal_standard_v2" {
  command = plan

  variables {
    sku_name = "StandardV2"
    zones    = ["1"]
  }

  expect_failures = [var.zones]
}

run "ipv6_idle_timeout" {
  command = plan

  variables {
    ip_version              = "IPv6"
    idle_timeout_in_minutes = 10
  }

  expect_failures = [var.idle_timeout_in_minutes]
}

run "internet_routing_for_ipv6" {
  command = plan

  variables {
    ip_version = "IPv6"
    ip_tags    = { RoutingPreference = "Internet" }
  }

  expect_failures = [var.ip_tags]
}

run "internet_routing_for_standard_v2" {
  command = plan

  variables {
    sku_name = "StandardV2"
    ip_tags  = { RoutingPreference = "Internet" }
  }

  expect_failures = [var.ip_tags]
}

run "reverse_dns_for_ipv6" {
  command = plan

  variables {
    ip_version        = "IPv6"
    domain_name_label = "pip-test"
    reverse_fqdn      = "www.example.com."
  }

  expect_failures = [var.reverse_fqdn]
}

run "invalid_ip_version" {
  command = plan

  variables {
    ip_version = "IPv5"
  }

  expect_failures = [var.ip_version]
}

run "idle_timeout_too_short" {
  command = plan

  variables {
    idle_timeout_in_minutes = 3
  }

  expect_failures = [var.idle_timeout_in_minutes]
}

run "invalid_domain_name_label" {
  command = plan

  variables {
    domain_name_label = "Pip_Test"
  }

  expect_failures = [var.domain_name_label]
}

run "scope_without_label" {
  command = plan

  variables {
    domain_name_label_scope = "TenantReuse"
  }

  expect_failures = [var.domain_name_label_scope]
}

run "reverse_fqdn_without_label" {
  command = plan

  variables {
    reverse_fqdn = "www.example.com."
  }

  expect_failures = [var.reverse_fqdn]
}

run "ddos_plan_without_enabled_mode" {
  command = plan

  variables {
    ddos_protection_plan_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/ddosProtectionPlans/ddos-test"
  }

  expect_failures = [var.ddos_protection_plan_id]
}

run "invalid_prefix_id" {
  command = plan

  variables {
    public_ip_prefix_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/pip-other"
  }

  expect_failures = [var.public_ip_prefix_id]
}

run "invalid_lock_kind" {
  command = plan

  variables {
    lock = { kind = "Delete" }
  }

  expect_failures = [var.lock]
}
