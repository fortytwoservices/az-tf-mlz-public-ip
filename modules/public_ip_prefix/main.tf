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
    # Sorted, so listing the same zones in another order does not trigger a replacement.
    var.zones == null ? {} : { zones = sort(distinct(var.zones)) },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_public_ip_prefixes) > 0 ? var.ignore_body_changes.network_public_ip_prefixes : null
  # Properties Azure cannot change on an existing prefix (the ones azurerm marks ForceNew); the SKU name
  # is updated in place.
  replace_triggers_refs = [
    "sku.tier",
    "zones",
    "properties.prefixLength",
    "properties.publicIPAddressVersion",
    "properties.customIPPrefix",
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
