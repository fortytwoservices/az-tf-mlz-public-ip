# az-tf-mlz-public-ip

A Fortytwo managed landing zone (MLZ) module for Azure public IP addresses, in AzAPI. The root module
manages one public IP address (`Microsoft.Network/publicIPAddresses`); `modules/public_ip_prefix`
manages a public IP prefix and is called on its own.

- Standard or StandardV2 SKU, Regional or Global tier; the address is always static.
- Zones default to Azure's default (zone-redundant where the region has availability zones); set
  `zones` for a zonal address.
- Optional DNS label (with reuse scope), reverse FQDN, DDoS protection settings, IP tags, and an
  address taken from a prefix (`public_ip_prefix_id`).
- Lock, role assignments and diagnostic settings, as in Azure Verified Modules. Changing the diagnostic
  settings or role assignments of a locked address removes the lock, makes the change and locks it
  again, because a lock blocks deleting them. To force-replace one of them (`-replace`), also replace
  `time_sleep.lock_removal[0]` in the same run. A `ReadOnly` lock also blocks changes to the address
  itself: set `lock = null`, apply your change, then lock it again.
- Changing the SKU, zones, IP version, prefix, IP tags or DNS label scope replaces the address, because
  Azure cannot change them in place.

```hcl
module "public_ip" {
  source = "git::https://github.com/fortytwoservices/az-tf-mlz-public-ip.git?ref=vX.Y.Z"

  name      = "pip-example"
  parent_id = "/subscriptions/<subscription>/resourceGroups/<resource group>"
  location  = "norwayeast"
}
```

The examples show a prefix with addresses taken from it, and the interfaces.
