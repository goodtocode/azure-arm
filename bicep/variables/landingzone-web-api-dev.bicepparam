using '../templates/landingzone-web-api.bicep'
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

// Mgmt Resource Group (hub)
param hubMgmtSubscriptionId = '00000000-0000-0000-0000-000000000000'
param hubMgmtResourceGroupName = '${tenantIac}-hubmgmt-prod-${instanceIac}-rg'

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spokemgmt-${environmentIac}-${instanceIac}-rg'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// App Service
param webName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-web'
param apiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-api'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
