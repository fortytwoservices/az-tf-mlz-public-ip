output "fqdn" {
  description = "Fully qualified domain name of the address's A record, or null without `domain_name_label`."
  value       = try(azapi_resource.this.output.properties.dnsSettings.fqdn, null)
}

output "ip_address" {
  description = "The public IP address."
  value       = azapi_resource.this.output.properties.ipAddress
}

output "name" {
  description = "Name of the public IP address."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the public IP address."
  value       = azapi_resource.this.id
}
