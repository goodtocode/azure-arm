using '../templates/landingzone-stapp.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'

param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Mgmt Resource Group (spoke)
param mgmtResourceGroupName = '${tenantIac}-spokemgmt-${environmentIac}-${instanceIac}-rg'
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-law'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// Storage
param stName = '${productIac}${environmentIac}${regionIac}${instanceIac}st'
param stSku = 'Standard_LRS'

// Key Vault
param kvName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-kv'
param kvSku = 'standard'

// Static Web App
param stappName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-stapp'
param repositoryUrl = ''
