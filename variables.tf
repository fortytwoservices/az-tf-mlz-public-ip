variable "location" {
  type        = string
  description = "Azure region of the public IP address, for example `norwayeast`."
  nullable    = false
}

variable "name" {
  type        = string
  description = "Name of the public IP address."
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9]([a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_])?$", var.name))
    error_message = "`name` must be 1 to 80 characters: letters, digits, underscores, periods and hyphens, starting with a letter or digit and ending with a letter, digit or underscore."
  }
}

variable "parent_id" {
  type        = string
  description = "Resource ID of the resource group the public IP address is created in."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "`parent_id` must be a resource group resource ID."
  }
}

variable "ddos_protection_mode" {
  type        = string
  default     = "VirtualNetworkInherited"
  description = "DDoS protection mode: `VirtualNetworkInherited` (Azure's default), `Enabled` or `Disabled`."
  nullable    = false

  validation {
    condition     = contains(["VirtualNetworkInherited", "Enabled", "Disabled"], var.ddos_protection_mode)
    error_message = "`ddos_protection_mode` must be `VirtualNetworkInherited`, `Enabled` or `Disabled`."
  }
}

variable "ddos_protection_plan_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of the DDoS protection plan. Requires `ddos_protection_mode = \"Enabled\"`."

  validation {
    condition     = var.ddos_protection_plan_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/ddosProtectionPlans", var.ddos_protection_plan_id))
    error_message = "`ddos_protection_plan_id` must be a DDoS protection plan resource ID."
  }
  validation {
    condition     = var.ddos_protection_plan_id == null || var.ddos_protection_mode == "Enabled"
    error_message = "`ddos_protection_plan_id` can only be set with `ddos_protection_mode = \"Enabled\"`."
  }
}

variable "domain_name_label" {
  type        = string
  default     = null
  description = "(Optional) Domain name label. Azure creates an A record `<label>.<region>.cloudapp.azure.com` for the address (with a hash when `domain_name_label_scope` is set)."

  validation {
    condition     = var.domain_name_label == null ? true : can(regex("^[a-z][a-z0-9-]{1,61}[a-z0-9]$", var.domain_name_label))
    error_message = "`domain_name_label` must be 3 to 63 lowercase letters, digits and hyphens, starting with a letter and ending with a letter or digit."
  }
}

variable "domain_name_label_scope" {
  type        = string
  default     = null
  description = "(Optional) Scope in which the hashed domain name label is reused: `TenantReuse`, `SubscriptionReuse`, `ResourceGroupReuse` or `NoReuse`. Requires `domain_name_label`. Changing it, including setting or removing it later, replaces the public IP address."

  validation {
    condition     = var.domain_name_label_scope == null ? true : contains(["TenantReuse", "SubscriptionReuse", "ResourceGroupReuse", "NoReuse"], var.domain_name_label_scope)
    error_message = "`domain_name_label_scope` must be `TenantReuse`, `SubscriptionReuse`, `ResourceGroupReuse`, `NoReuse` or null."
  }
  validation {
    condition     = var.domain_name_label_scope == null || var.domain_name_label != null
    error_message = "`domain_name_label_scope` requires `domain_name_label`."
  }
}

variable "idle_timeout_in_minutes" {
  type        = number
  default     = 4
  description = "Idle timeout of TCP connections in minutes, 4 to 30."
  nullable    = false

  validation {
    condition     = var.idle_timeout_in_minutes >= 4 && var.idle_timeout_in_minutes <= 30 && floor(var.idle_timeout_in_minutes) == var.idle_timeout_in_minutes
    error_message = "`idle_timeout_in_minutes` must be a whole number from 4 to 30."
  }
  validation {
    condition     = var.ip_version == "IPv4" || var.idle_timeout_in_minutes == 4
    error_message = "An IPv6 address has a fixed idle timeout of 4 minutes (Microsoft Learn)."
  }
}

variable "ip_tags" {
  type        = map(string)
  default     = {}
  description = "IP tags, keyed by tag type, for example `{ RoutingPreference = \"Internet\" }` (Standard IPv4 only). Changing them replaces the public IP address."
  nullable    = false

  validation {
    condition     = lookup(var.ip_tags, "RoutingPreference", null) != "Internet" || (var.sku_name == "Standard" && var.ip_version == "IPv4")
    error_message = "Routing preference Internet is supported only for Standard IPv4 addresses (Microsoft Learn)."
  }
}

variable "ip_version" {
  type        = string
  default     = "IPv4"
  description = "IP version: `IPv4` or `IPv6`. Changing it replaces the public IP address."
  nullable    = false

  validation {
    condition     = contains(["IPv4", "IPv6"], var.ip_version)
    error_message = "`ip_version` must be `IPv4` or `IPv6`."
  }
}

variable "public_ip_prefix_id" {
  type        = string
  default     = null
  description = "(Optional) Resource ID of the public IP prefix to take the address from (see `modules/public_ip_prefix`). Its SKU must match `sku_name`. Changing it replaces the public IP address."

  validation {
    condition     = var.public_ip_prefix_id == null ? true : can(provider::azapi::parse_resource_id("Microsoft.Network/publicIPPrefixes", var.public_ip_prefix_id))
    error_message = "`public_ip_prefix_id` must be a public IP prefix resource ID."
  }
}

variable "reverse_fqdn" {
  type        = string
  default     = null
  description = "(Optional) Reverse FQDN: Azure creates a PTR record from the address to this name, which must resolve to the address or to this public IP's FQDN. Requires `domain_name_label`."

  validation {
    condition     = var.reverse_fqdn == null || var.domain_name_label != null
    error_message = "`reverse_fqdn` requires `domain_name_label` (Azure needs a label in every dnsSettings section)."
  }
  validation {
    condition     = var.reverse_fqdn == null || var.ip_version == "IPv4"
    error_message = "Reverse DNS is not supported for IPv6 addresses (Microsoft Learn)."
  }
}

variable "sku_name" {
  type        = string
  default     = "Standard"
  description = "SKU name: `Standard` or `StandardV2` (needed with NAT gateway v2). Basic is retired. Changing it replaces the public IP address."
  nullable    = false

  validation {
    condition     = contains(["Standard", "StandardV2"], var.sku_name)
    error_message = "`sku_name` must be `Standard` or `StandardV2`."
  }
}

variable "sku_tier" {
  type        = string
  default     = "Regional"
  description = "SKU tier: `Regional`, or `Global` for the front end of a cross-region load balancer (Standard SKU only, no zones). Changing it replaces the public IP address."
  nullable    = false

  validation {
    condition     = contains(["Regional", "Global"], var.sku_tier)
    error_message = "`sku_tier` must be `Regional` or `Global`."
  }
  validation {
    condition     = var.sku_tier == "Regional" || (var.sku_name == "Standard" && var.zones == null)
    error_message = "A `Global` tier address needs `sku_name = \"Standard\"` and no `zones`."
  }
}

variable "zones" {
  type        = list(string)
  default     = null
  description = "(Optional) Availability zones, for example `[\"1\", \"2\", \"3\"]` (zone-redundant) or `[\"1\"]` (zonal). When null, Azure's default applies: zone-redundant in regions with availability zones, non-zonal elsewhere. Changing the zones replaces the public IP address."

  validation {
    condition     = var.zones == null ? true : length(var.zones) > 0 && alltrue([for zone in var.zones : contains(["1", "2", "3"], zone)])
    error_message = "`zones` must be null or a non-empty list of \"1\", \"2\" and \"3\"."
  }
  validation {
    condition     = var.zones == null || var.sku_name != "StandardV2" ? true : length(distinct(var.zones)) == 3
    error_message = "A StandardV2 address can only be zone-redundant: leave `zones` null or set all three (Microsoft Learn)."
  }
}
