using '../templates/platform-hub-edge-appgateway.bicep'

// =====================
// Common
// =====================
var tenantIac = 'ScopeOrTenant'
var productIac = 'edge'
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
// Edge RG: ${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// rg: ScopeOrTenant-hub-edge-plat-wus2-001
// =====================
param hubNetworkResourceGroupName = 'network-${environmentIac}-${regionIac}-${instanceIac}-rg'
param vnetName = 'network-${environmentIac}-${regionIac}-${instanceIac}-vnet'
param snetNameAppGateway = '${productIac}-appgateway-${instanceIac}-snet'
param snetCidrAppGateway = '10.0.3.0/24'
param snetCidrAzureFirewall = '10.0.4.0/26'

param agwName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-agw'
param agwMinCapacity = 1
param agwMaxCapacity = 2
param wafMode = 'Prevention'

param firewallName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-fw'
param firewallTier = 'Standard'
param firewallThreatIntelMode = 'Alert'

param ddosIpProtection = false

// One entry per product. The gateway deploys only when this list is not empty.
param backends = [
  // {
  //   name: 'compass'
  //   hostName: 'compass.censic.cloud'
  //   backendFqdn: 'compass-prod.azurewebsites.net'
  // }
]
