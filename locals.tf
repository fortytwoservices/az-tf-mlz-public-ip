locals {
  zones = var.zones == null ? null : sort(distinct(var.zones))
}
