resource "azapi_resource" "this" {
  type      = var.resource_types.network_public_ip_addresses
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
          idleTimeoutInMinutes     = var.idle_timeout_in_minutes
          ipTags                   = [for type, tag in var.ip_tags : { ipTagType = type, tag = tag }]
          publicIPAddressVersion   = var.ip_version
          publicIPAllocationMethod = "Static" # the only method the Standard SKUs support
        },
        # Optional blocks are sent only when set, so Azure's defaults apply and the plan stays clean.
        length(local.dns_settings) > 0 ? { dnsSettings = local.dns_settings } : {},
        length(local.ddos_settings) > 0 ? { ddosSettings = local.ddos_settings } : {},
        var.public_ip_prefix_id == null ? {} : { publicIPPrefix = { id = var.public_ip_prefix_id } },
      )
    },
    var.zones == null ? {} : { zones = var.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_public_ip_addresses) > 0 ? var.ignore_body_changes.network_public_ip_addresses : null
  # Properties Azure cannot change on an existing address (the ones azurerm marks ForceNew).
  replace_triggers_refs = [
    "sku",
    "zones",
    "properties.publicIPAddressVersion",
    "properties.publicIPPrefix",
    "properties.ipTags",
    "properties.dnsSettings.domainNameLabelScope",
  ]
  response_export_values = ["properties.ipAddress", "properties.dnsSettings.fqdn"]
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
