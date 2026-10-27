# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Proves what mocks cannot: the default API version and body (explicit nulls included) are accepted, an
# in-place update keeps the address, cleared settings are cleared in Azure, children can be removed while
# the address stays locked, zone changes in both directions replace it, and everything is destroyed.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name              = "pip-mlz-it-${run.setup.suffix}"
    parent_id         = run.setup.resource_group_id
    location          = run.setup.location
    domain_name_label = "pip-mlz-it-${run.setup.suffix}"
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  assert {
    condition     = can(cidrhost("${output.ip_address}/32", 0))
    error_message = "An IPv4 address should be read back from Azure."
  }
  assert {
    condition     = output.fqdn == "pip-mlz-it-${run.setup.suffix}.norwayeast.cloudapp.azure.com"
    error_message = "The FQDN should be built from the DNS label and the region."
  }
}

run "replace_child_under_lock" {
  # A child replaced without an input change (as with -replace) also needs the lock out of the way: the
  # documented way is to replace the pause in the same run, which recreates the lock around it.
  variables {
    name              = "pip-mlz-it-${run.setup.suffix}"
    parent_id         = run.setup.resource_group_id
    location          = run.setup.location
    domain_name_label = "pip-mlz-it-${run.setup.suffix}"
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
  }

  plan_options {
    replace = [module.interfaces.azapi_resource.diagnostic_settings["workspace"], module.interfaces.time_sleep.lock_removal[0]]
  }

  assert {
    condition     = length(module.interfaces.diagnostic_setting_resource_ids) == 1 && module.interfaces.lock_resource_id != null
    error_message = "The diagnostic setting should be recreated and the lock back."
  }
}

run "update_in_place" {
  variables {
    name                    = "pip-mlz-it-${run.setup.suffix}"
    parent_id               = run.setup.resource_group_id
    location                = run.setup.location
    domain_name_label       = "pip-mlz-it-${run.setup.suffix}"
    idle_timeout_in_minutes = 10
    diagnostic_settings = {
      workspace = {
        workspace_resource_id = run.setup.workspace_id
        logs                  = [{ category_group = "allLogs" }]
        metrics               = [{ category = "AllMetrics" }]
      }
    }
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "Reader", principal_id = run.setup.object_id }
    }
    tags = { updated = "true" }
  }

  assert {
    condition     = output.ip_address == run.create.ip_address
    error_message = "An idle timeout and tag change should update the address in place and keep it."
  }
}

run "clear_settings_and_remove_children_under_lock" {
  # The DNS label is cleared (sent as null, not left out) and the diagnostic setting and role assignment
  # are deleted while the lock stays configured: the lock is removed and created again around them.
  variables {
    name                    = "pip-mlz-it-${run.setup.suffix}"
    parent_id               = run.setup.resource_group_id
    location                = run.setup.location
    idle_timeout_in_minutes = 10
    lock                    = { kind = "CanNotDelete" }
    tags                    = { updated = "true" }
  }

  assert {
    condition     = output.fqdn == null && output.ip_address == run.create.ip_address
    error_message = "The DNS label should be removed in Azure, with the address kept."
  }
  assert {
    condition     = length(module.interfaces.diagnostic_setting_resource_ids) + length(module.interfaces.role_assignment_resource_ids) == 0 && module.interfaces.lock_resource_id != null
    error_message = "The diagnostic setting and role assignment should be gone, and the lock back."
  }
}

run "zonal_replaces_the_address" {
  # Azure cannot change the zones of an address; without the replace trigger this apply would fail.
  variables {
    name      = "pip-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    zones     = ["1"]
    lock      = { kind = "CanNotDelete" }
  }

  assert {
    condition     = azapi_resource.this.body.zones == tolist(["1"]) && output.fqdn == null
    error_message = "The address should be recreated in zone 1, without the DNS label."
  }
}

run "default_zones_replace_the_address" {
  # Setting zones back to null drops them from the body; the replacement input still sees the change.
  variables {
    name      = "pip-mlz-it-${run.setup.suffix}"
    parent_id = run.setup.resource_group_id
    location  = run.setup.location
    lock      = { kind = "CanNotDelete" }
  }
}

run "zones_read_back" {
  module {
    source = "./tests/integration/read"
  }

  variables {
    public_ip_address_id = run.default_zones_replace_the_address.resource_id
  }

  assert {
    condition     = try(output.zones, null) != tolist(["1"])
    error_message = "The address should no longer be zonal (zone 1) after zones were set back to null."
  }
}
