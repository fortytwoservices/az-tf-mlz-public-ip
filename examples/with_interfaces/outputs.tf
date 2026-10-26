output "fqdn" {
  description = "Fully qualified domain name of the address's A record."
  value       = module.public_ip.fqdn
}

output "ip_address" {
  description = "The public IP address."
  value       = module.public_ip.ip_address
}
