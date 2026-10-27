# Public IP prefix

One public IP prefix (`Microsoft.Network/publicIPPrefixes`): a reserved, contiguous range of Standard
public IP addresses, /28 to /31 for IPv4 and /124 to /127 for IPv6. Call it directly, then create the
addresses with the root module and `public_ip_prefix_id`.

Lock, role assignments and diagnostic settings are supported, through
[`az-tf-mlz-interfaces`](https://github.com/fortytwoservices/az-tf-mlz-interfaces) as in the root
module. Changing the tier, zones, prefix length,
IP version or custom IP prefix replaces the prefix; the SKU name is changed in place.
