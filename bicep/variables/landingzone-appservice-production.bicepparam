using '../templates/landingzone-appservice.bicep'
// Common
var subscriptionName = 'production'
var productName = 'PRODUCT'
var environmentIac = 'prod'
param environmentApp = 'Production'
param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }
// Workspace
param sharedResourceGroupName = 'rg-${subscriptionName}-shared-${environmentIac}-001'
param workName = 'work-shared-${environmentIac}-001'

// Azure Monitor
param appiName = 'appi-${productName}-${environmentIac}-001'
param Flow_Type = 'Bluefield'
param Application_Type = 'web'

// Storage
param stName = 'st${productName}${environmentIac}001'
param stSku = 'Standard_LRS'

// Key Vault
param kvName = 'kv-${productName}-${environmentIac}-001'
param kvSku = 'standard'

// App Service
var planSku = 'F1'
param appName = 'api-${productName}-${environmentIac}-001'
param planName = 'plan-shared-${environmentIac}-${planSku}-001'
