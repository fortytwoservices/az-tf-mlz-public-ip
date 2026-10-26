# Real Azure, no mocks: ARM_SUBSCRIPTION_ID=<test subscription> scripts/integration.sh modules/public_ip_prefix
# Proves the prefix works when called alone, is updated in place, and gives addresses to the root module.

run "setup" {
  module {
    source = "./tests/integration/setup"
  }
}

run "create" {
  variables {
    name          = "ippre-mlz-it-${run.setup.suffix}"
    parent_id     = run.setup.resource_group_id
    location      = run.setup.location
    prefix_length = 31
    lock          = { kind = "CanNotDelete" }
  }

  assert {
    condition     = endswith(output.ip_prefix, "/31")
    error_message = "A /31 range should be read back from Azure."
  }
}

run "update_in_place" {
  variables {
    name          = "ippre-mlz-it-${run.setup.suffix}"
    parent_id     = run.setup.resource_group_id
    location      = run.setup.location
    prefix_length = 31
    lock          = { kind = "CanNotDelete" }
    tags          = { updated = "true" }
  }

  assert {
    condition     = output.ip_prefix == run.create.ip_prefix
    error_message = "A tag change should update the prefix in place and keep its range."
  }
}

run "address_from_prefix" {
  module {
    source = "../.."
  }

  variables {
    name                = "pip-mlz-it-${run.setup.suffix}"
    parent_id           = run.setup.resource_group_id
    location            = run.setup.location
    public_ip_prefix_id = run.update_in_place.resource_id
  }

  assert {
    condition     = contains([cidrhost(run.update_in_place.ip_prefix, 0), cidrhost(run.update_in_place.ip_prefix, 1)], output.ip_address)
    error_message = "The address should come from the prefix."
  }
}
