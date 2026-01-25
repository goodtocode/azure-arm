using '../templates/platform-spoke-mgmt.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'SPOKE-PURPOSE-OR-PRODUCT'
var environmentIac = 'prod'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'West US 2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Hub
// =====================
param mgmtSubscriptionId = '00000000-0000-0000-0000-000000000000'
param mgmtResourceGroupName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-mgmt-rg'
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sent'

// =====================
// Management
// =====================
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'
param kvName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-kv'
param kvSku = 'standard'
param appcsName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appcs'
param appcsSku = 'free'
