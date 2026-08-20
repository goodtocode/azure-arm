using '../templates/landingzone-web-api.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Mgmt Resource Group (hub)
param hubMgmtSubscriptionId = '00000000-0000-0000-0000-000000000000'
param hubMgmtResourceGroupName = '${tenantIac}-hub-mgmt-plat-${regionIac}-${instanceIac}-rg'

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
param appiName = 'spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'

// App Service
param webName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-web'
param apiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-api'
param planName = 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
