module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  enable_telemetry       = false # defaults to true
  location               = var.location
  diagnostic_settings_v2 = var.diagnostic_settings
  lock                   = var.lock
  role_assignments       = local.role_assignments
  # Role definitions are looked up by name in the resource group, which exists before the public IP
  # address, so an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
}

resource "azapi_resource" "diagnostic_settings" {
  for_each = module.interfaces.diagnostic_settings_azapi_v2

  type                 = var.resource_types.insights_diagnostic_settings
  name                 = coalesce(each.value.name, "diag-${each.key}")
  parent_id            = azapi_resource.this.id
  body                 = each.value.body
  ignore_body_changes  = length(var.ignore_body_changes.insights_diagnostic_settings) > 0 ? var.ignore_body_changes.insights_diagnostic_settings : null
  ignore_null_property = true
  # Azure also returns the type's log categories (or category groups) that were not requested, disabled,
  # which azapi would plan to remove on every run. Match entries by category instead of by position and
  # ignore the extra ones (seen on public IPs: allLogs requested, audit returned disabled).
  ignore_other_items_in_list = ["properties.logs", "properties.metrics"]
  list_unique_id_property = {
    "properties.logs"    = "category,categoryGroup"
    "properties.metrics" = "category"
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}

resource "azapi_resource" "role_assignments" {
  for_each = module.interfaces.role_assignments_azapi

  type                 = var.resource_types.authorization_role_assignments
  name                 = each.value.name
  parent_id            = azapi_resource.this.id
  body                 = each.value.body
  ignore_body_changes  = length(var.ignore_body_changes.authorization_role_assignments) > 0 ? var.ignore_body_changes.authorization_role_assignments : null
  ignore_casing        = true
  ignore_null_property = true
  # An existing role assignment cannot be changed (RoleAssignmentUpdateNotPermitted), so a new principal,
  # role or delegated identity replaces it. A changed explicit name does too, despite
  # `ignore_changes = [name]` below; a generated name stays null here.
  replace_triggers_external_values = {
    delegated_managed_identity_resource_id = var.role_assignments[each.key].delegated_managed_identity_resource_id
    name                                   = var.role_assignments[each.key].name
    principal_id                           = lower(var.role_assignments[each.key].principal_id)
    role_definition_id_or_name             = lower(var.role_assignments[each.key].role_definition_id_or_name)
  }
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    ignore_changes = [name] # random UUID names; keeps imported names stable
  }
}

resource "azapi_resource" "lock" {
  count = var.lock != null ? 1 : 0

  type                   = var.resource_types.authorization_locks
  name                   = coalesce(module.interfaces.lock_azapi.name, "lock-${var.lock.kind}")
  parent_id              = azapi_resource.this.id
  body                   = module.interfaces.lock_azapi.body
  ignore_body_changes    = length(var.ignore_body_changes.authorization_locks) > 0 ? var.ignore_body_changes.authorization_locks : null
  ignore_null_property   = true
  response_export_values = []
  retry                  = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  # Created last and removed first: a lock also blocks writes to the resources under the address.
  depends_on = [time_sleep.lock_removal]
}

# Azure keeps enforcing a deleted lock for a few seconds. Destroyed after the lock and before everything
# else, this pause lets the deletion propagate first. The trigger replaces it with the address, so the
# pause also runs when a locked address is replaced.
resource "time_sleep" "lock_removal" {
  count = var.lock != null ? 1 : 0

  destroy_duration = "30s"
  triggers = {
    public_ip_address_id = azapi_resource.this.id
  }

  depends_on = [
    azapi_resource.diagnostic_settings,
    azapi_resource.role_assignments,
  ]
}
