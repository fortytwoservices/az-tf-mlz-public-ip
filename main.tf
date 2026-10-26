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
      # Optional settings are always sent, null when unset. Leaving a removed setting out would not clear
      # it: azapi's ignore_no_op_changes compares only the keys in the configuration, so the plan would
      # be empty and Azure would keep the old value.
      properties = {
        ddosSettings = {
          ddosProtectionPlan = var.ddos_protection_plan_id == null ? null : { id = var.ddos_protection_plan_id }
          protectionMode     = var.ddos_protection_mode
        }
        # Azure rejects a dnsSettings section without a label (DomainNameLabelMissing), so without a label
        # the whole section is null.
        dnsSettings = var.domain_name_label == null ? null : {
          domainNameLabel      = var.domain_name_label
          domainNameLabelScope = var.domain_name_label_scope
          reverseFqdn          = var.reverse_fqdn
        }
        idleTimeoutInMinutes     = var.idle_timeout_in_minutes
        ipTags                   = [for type, tag in var.ip_tags : { ipTagType = type, tag = tag }]
        publicIPAddressVersion   = var.ip_version
        publicIPAllocationMethod = "Static" # the only method the Standard SKUs support
        publicIPPrefix           = var.public_ip_prefix_id == null ? null : { id = var.public_ip_prefix_id }
      }
    },
    # Left out when null, so the zones Azure picks are not compared with the configuration. Sorted, so
    # listing the same zones in another order changes nothing.
    var.zones == null ? {} : { zones = local.zones },
  )
  ignore_body_changes = length(var.ignore_body_changes.network_public_ip_addresses) > 0 ? var.ignore_body_changes.network_public_ip_addresses : null
  # Properties Azure cannot change on an existing address (the ones azurerm marks ForceNew). The nullable
  # ones are compared as inputs rather than body paths, so that setting them back to null also replaces
  # the address (a removed body path is ignored, as above).
  replace_triggers_external_values = {
    domain_name_label_scope = var.domain_name_label_scope
    public_ip_prefix_id     = var.public_ip_prefix_id
    zones                   = local.zones
  }
  replace_triggers_refs = [
    "sku",
    "properties.publicIPAddressVersion",
    "properties.ipTags",
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
