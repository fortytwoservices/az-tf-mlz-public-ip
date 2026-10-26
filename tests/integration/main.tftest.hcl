# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh .
# Proves what mocks cannot: the default API version and body are accepted, an in-place update keeps the
# address, a zone change replaces it (with a lock in place), and everything is destroyed cleanly.

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
