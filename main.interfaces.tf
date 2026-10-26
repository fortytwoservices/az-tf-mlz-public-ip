module "interfaces" {
  source  = "Azure/avm-utl-interfaces/azure"
  version = "0.9.0"

  enable_telemetry = false # defaults to true
  location         = var.location
  lock             = var.lock
  role_assignments = local.role_assignments
  # Role definitions are looked up by name in the resource group, which exists before the identity, so
  # an unknown role name fails during plan.
  role_assignment_definition_scope = var.parent_id
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

  # Created last and removed first: a lock also blocks writes to the resources under the identity.
  depends_on = [time_sleep.lock_removal]
}

# Azure keeps enforcing a deleted lock for a few seconds. Destroyed after the lock and before everything
# else, this pause lets the deletion propagate first. The trigger replaces it with the identity, so the
# pause also runs when a locked identity is replaced.
resource "time_sleep" "lock_removal" {
  count = var.lock != null ? 1 : 0

  destroy_duration = "30s"
  triggers = {
    identity_id = azapi_resource.this.id
  }

  depends_on = [
    azapi_resource.this,
    azapi_resource.role_assignments,
    module.federated_identity_credential,
  ]
}
