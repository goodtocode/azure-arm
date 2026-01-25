using '../templates/platform-hub-mgmt.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'platform'
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
// Management
// =====================
param sentName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sent'
param sentSku = 'PerGB2018'
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'
param kvName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-kv'
param kvSku = 'standard'
