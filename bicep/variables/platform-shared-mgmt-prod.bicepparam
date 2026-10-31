using '../templates/platform-shared-mgmt.bicep'

// Phase 2: shared management for the production subscription. Public endpoints, no VNet.
// RG: {product/purpose}-{env}-{region}-{instance}-rg, i.e. mgmt-prod-wus2-001-rg
var productIac = 'mgmt'
var environmentIac = 'prod'
var regionIac = 'wus2'
var instanceIac = '001'
var planSkuIac = 'B1'
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: 'ScopeOrTenant'
}

// Phase 3: set hubMgmtSubscriptionId and hubMgmtResourceGroupName to use the platform workspace instead.
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-law'
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'
param appcsName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appcs'
param appcsSku = 'free'
param kvName = '${productIac}-${environmentIac}-${instanceIac}-kv'
param planSku = planSkuIac
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSkuIac}-${instanceIac}-plan'
param networkAccess = 'public'
