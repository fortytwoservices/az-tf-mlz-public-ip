output "ip_address" {
  description = "The public IP address."
  value       = module.public_ip.ip_address
}

output "resource_id" {
  description = "Resource ID of the public IP address."
  value       = module.public_ip.resource_id
}
