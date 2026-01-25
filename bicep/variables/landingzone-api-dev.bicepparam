using '../templates/landingzone-api.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spokemgmt-${environmentIac}-${instanceIac}-rg'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// App Service
param appName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-api'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
