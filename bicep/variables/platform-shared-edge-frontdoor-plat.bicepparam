using '../templates/platform-shared-edge-frontdoor.bicep'

// =====================
// Common
// =====================
var tenantIac = 'ScopeOrTenant'
var productIac = 'edge'
var environmentIac = 'plat'
var instanceIac = '001'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Edge RG: {product/purpose}-{env}-{region}-{instance}-rg
// rg: edge-plat-wus2-001-rg
// =====================
param afdName = '${tenantIac}-${productIac}-${environmentIac}-${instanceIac}-afd'
param afdSku = 'Premium_AzureFrontDoor'
param wafMode = 'Prevention'
param wafRateLimitThreshold = 0

// One entry per product. Use a separate hostname per product, e.g. compass.censic.cloud.
param origins = [
  // {
  //   name: 'compass'
  //   originHostName: 'compass-prod.azurewebsites.net'
  //   customDomainHostName: 'compass.censic.cloud'
  // }
]
