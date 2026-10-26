variable "location" {
  type        = string
  description = "Azure region of the public IP prefix, for example `norwayeast`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the public IP prefix."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the public IP prefix is created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "prefix_length" {
  type        = number
  description = "Prefix length: 28 to 31 for IPv4 (16 to 2 addresses), 124 to 127 for IPv6. Larger prefixes only from a custom IP prefix (`custom_ip_prefix_id`). Changing it replaces the prefix."
  nullable    = false

  validation {
    condition = var.custom_ip_prefix_id != null ? (var.ip_version == "IPv4" ? var.prefix_length >= 1 && var.prefix_length <= 31 : var.prefix_length >= 1 && var.prefix_length <= 127) : (
      var.ip_version == "IPv4" ? var.prefix_length >= 28 && var.prefix_length <= 31 : var.prefix_length >= 124 && var.prefix_length <= 127
    )
    error_message = "`prefix_length` must be 28 to 31 for IPv4 or 124 to 127 for IPv6, unless the prefix comes from a custom IP prefix."
  }
}

variable "custom_ip_prefix_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of the custom IP prefix (your own range, BYOIP) to take the prefix from. Changing, setting or removing it replaces the prefix."

  validation {
    condition     = var.custom_ip_prefix_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/customIPPrefixes", var.custom_ip_prefix_id))
    error_message = "`custom_ip_prefix_id` must be a custom IP prefix resource ID."
  }
}

variable "ip_version" {
  type        = string
  default     = "IPv4"
  description = "IP version: `IPv4` or `IPv6`. Changing it replaces the prefix."
  nullable    = false

  validation {
    condition     = contains(["IPv4", "IPv6"], var.ip_version)
    error_message = "`ip_version` must be `IPv4` or `IPv6`."
  }
}

variable "sku_name" {
  type        = string
  default     = "Standard"
  description = "SKU name: `Standard`, or `StandardV2` for NAT gateway v2. Addresses taken from the prefix must have the same SKU."
  nullable    = false

  validation {
    condition     = contains(["Standard", "StandardV2"], var.sku_name)
    error_message = "`sku_name` must be `Standard` or `StandardV2`."
  }
}

variable "sku_tier" {
  type        = string
  default     = "Regional"
  description = "SKU tier: `Regional`, or `Global` for cross-region load balancer front ends (Standard SKU only, no zones). Changing it replaces the prefix."
  nullable    = false

  validation {
    condition     = contains(["Regional", "Global"], var.sku_tier)
    error_message = "`sku_tier` must be `Regional` or `Global`."
  }
  validation {
    condition     = var.sku_tier == "Regional" || (var.sku_name == "Standard" && var.zones == null)
    error_message = "A `Global` tier prefix needs `sku_name = \"Standard\"` and no `zones`."
  }
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "(Optional) Availability zones, for example `[\"1\", \"2\", \"3\"]` (zone-redundant) or `[\"1\"]` (zonal). When null, Azure's default applies: zone-redundant in regions with availability zones, non-zonal elsewhere. Changing the zones replaces the prefix."

  validation {
    condition     = var.zones == null ? true : length(var.zones) > 0 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "`zones` must be null or a non-empty list of \"1\", \"2\" and \"3\"."
  }
}
