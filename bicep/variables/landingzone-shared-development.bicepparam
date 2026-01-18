using '../templates/landingzone-shared.bicep'


// Common
var productIac = 'shared'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Workspace (Log Analytics)
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-law'
param workSku = 'PerGB2018'

// App Service Plan
param planSku = 'F1'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
