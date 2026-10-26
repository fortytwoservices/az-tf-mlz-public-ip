resource "azapi_resource" "this" {
  type      = var.resource_types.managedidentity_user_assigned_identities
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  # Federated identity credentials are child resources; ARM keeps them when the identity is written
  # without them. `properties` is sent only when set: API versions before 2024-11-30 have none to write.
  body                   = merge({}, var.isolation_scope == null ? {} : { properties = { isolationScope = var.isolation_scope } })
  ignore_body_changes    = length(var.ignore_body_changes.managedidentity_user_assigned_identities) > 0 ? var.ignore_body_changes.managedidentity_user_assigned_identities : null
  response_export_values = ["properties.principalId", "properties.clientId", "properties.tenantId"]
  retry                  = var.retry
  tags                   = var.tags

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
