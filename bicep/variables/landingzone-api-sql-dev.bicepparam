using '../templates/landingzone-api-sql.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'westus2'
var planSku = 'F1'
param tags = { Environment: environmentIac, CostCenter: '0000' }
param environmentApp = 'Development'

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
param appiName = 'spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'

// App Service
param appName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-api'
param planName = 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'

// SQL Server
param sqlName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sql'
param sqlAdminUser = 'LocalAdmin'
param sqlAdminPassword = 'PASS_FROM_CLI_PARAMETERS'
param sqldbName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sqldb'
param sqldbSku = 'Basic'
