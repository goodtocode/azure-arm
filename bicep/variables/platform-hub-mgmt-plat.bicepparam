using '../templates/platform-hub-mgmt.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'hub-mgmt'
var environmentIac = 'plat'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Management RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// rg: gtc-hub-mgmt-plat-wus2-001
// =====================
param sentName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sent'
param sentSku = 'PerGB2018'
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'
param kvName = '${productIac}-${environmentIac}-${instanceIac}-kv'
param kvSku = 'standard'
// Replace with the hub management subnet resource ID to enable private Key Vault access.
param kvAllowedVirtualNetworkResourceIds = [
  '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/hub-network-plat-wus2-001-rg/providers/Microsoft.Network/virtualNetworks/hub-plat-wus2-001-vnet/subnets/management-snet'
]
