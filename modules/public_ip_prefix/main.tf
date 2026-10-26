resource "azapi_resource" "this" {
  type      = var.resource_types.network_public_ip_prefixes
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  body = merge(
    {
      sku = {
        name = var.sku_name
        tier = var.sku_tier
      }
      properties = merge(
        {
          prefixLength           = var.prefix_length
          publicIPAddressVersion = var.ip_version
        },
        var.custom_ip_prefix_id == null ? {} : { customIPPrefix = { id = var.custom_ip_prefix_id } },
      )
    },
    # Left out when null, so the zones Azure picks are not compared with the configuration. Sorted, so
    # listing the same zones in another order changes nothing.
    var.zones == null ? {} : { zones = local.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_public_ip_prefixes) > 0 ? var.ignore_body_changes.network_public_ip_prefixes : null
  # Properties Azure cannot change on an existing prefix (the ones azurerm marks ForceNew); the SKU name
  # is updated in place. The nullable ones are compared as inputs rather than body paths, so that setting
  # them back to null also replaces the prefix: azapi's ignore_no_op_changes ignores a removed body path.
  replace_triggers_external_values = {
    custom_ip_prefix_id = var.custom_ip_prefix_id
    zones               = local.zones
  }
  replace_triggers_refs = [
    "sku.tier",
    "properties.prefixLength",
    "properties.publicIPAddressVersion",
  ]
  response_export_values = ["properties.ipPrefix"]
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
