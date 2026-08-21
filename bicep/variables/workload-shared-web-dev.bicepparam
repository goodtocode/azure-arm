using '../templates/workload-shared-web.bicep'

// Common
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Existing common services to wire the Web App to
param appiResourceGroupName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-shared-rg'
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'
param planResourceGroupName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-shared-rg'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'

// App Service
param webName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-web'

// Optional home resource group Storage Account
param storageAccountName = '${productIac}${environmentIac}${regionIac}${instanceIac}st'
param deployStorage = false
param storageSku = 'Standard_LRS'
