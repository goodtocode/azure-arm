using '../templates/landingzone-blazor-api-sql.bicep'
// Common

var tenantIac = 'myco'
var productIac = 'product'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Resource Group (shared)
param mgmtResourceGroupName = '${tenantIac}-${productIac}-${environmentIac}-${instanceIac}-rg'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// Storage
param stName = '${productIac}${environmentIac}${regionIac}${instanceIac}-st'
param stSku = 'Standard_LRS'

// App Service
param webName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-web'
param apiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-api'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'

// SQL Server
param sqlName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sql'
param sqlAdminUser = ''
param sqlAdminPassword = ''
param sqldbName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-sqldb'
param sqldbSku = 'Basic'
