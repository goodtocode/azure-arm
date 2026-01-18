using '../templates/landingzone-stapp.bicep'
// Common

var tenantIac = 'myco'
var productIac = 'product'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'

param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Resource Group (shared)
param sharedResourceGroupName = '${tenantIac}-${productIac}-${environmentIac}-${instanceIac}-rg'
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-law'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// Storage
param stName = '${productIac}${environmentIac}${regionIac}${instanceIac}-st'
param stSku = 'Standard_LRS'

// Key Vault
param kvName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-kv'
param kvSku = 'standard'

// Static Web App
param stappName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-stapp'
param repositoryUrl = ''
