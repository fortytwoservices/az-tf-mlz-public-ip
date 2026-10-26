output "ip_addresses" {
  description = "The public IP addresses taken from the prefix."
  value       = { for key, address in module.public_ip : key => address.ip_address }
}

output "ip_prefix" {
  description = "The prefix in CIDR notation."
  value       = module.public_ip_prefix.ip_prefix
}
