using '../templates/landingzone-web-sql.bicep'
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
param hubMgmtResourceGroupName = '${tenantIac}-platmgmt-${environmentIac}-${instanceIac}-rg'

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spokemgmt-${environmentIac}-${instanceIac}-rg'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// App Service
param webName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-web'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'

// SQL Server
param sqlName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sql'
param sqlAdminUser = ''
param sqlAdminPassword = ''
param sqldbName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sqldb'
param sqldbSku = 'Basic'
