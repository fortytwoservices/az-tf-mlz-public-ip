# Reads a public IP address's zones straight from Azure.
terraform {
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.12"
    }
  }
}

variable "public_ip_address_id" {
  type = string
}

data "azapi_resource" "public_ip_address" {
  type                   = "Microsoft.Network/publicIPAddresses@2025-07-01"
  resource_id            = var.public_ip_address_id
  response_export_values = ["zones"]
}

output "zones" {
  value = try(data.azapi_resource.public_ip_address.output.zones, null)
}
