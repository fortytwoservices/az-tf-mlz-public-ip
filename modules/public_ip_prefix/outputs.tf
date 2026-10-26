output "ip_prefix" {
  description = "The allocated range in CIDR notation, for example `20.100.0.0/31`."
  value       = azapi_resource.this.output.properties.ipPrefix
}

output "name" {
  description = "Name of the public IP prefix."
  value       = azapi_resource.this.name
}

output "resource_id" {
  description = "Resource ID of the public IP prefix."
  value       = azapi_resource.this.id
}
