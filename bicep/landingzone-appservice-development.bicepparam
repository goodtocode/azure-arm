using 'landingzone-appservice.bicep'
// Common
param tenantId = 'TENANT_ID'
param rgEnvironment = 'Development'
param location = 'West US 2'
param tags = { Environment: 'dev', CostCenter: '1111' }
// Workspace
param sharedSubscriptionId = 'SUBSCRIPTION_ID'
param sharedResourceGroupName = 'rg-microservices-dev-001'
param workName = 'work-microservices-dev-001'

// Azure Monitor
param appiName = 'appi-PRODUCT-dev-001'
param Flow_Type = 'Bluefield'
param skuName = 'standard'
param Application_Type = 'web'

// Storage
param storageName = 'stPRODUCTdev001'
param storageSkuName = 'Standard_LRS'

// Key Vault
param keyVaultName = 'kv-PRODUCT-dev-001'

// App Service
param appName = 'api-PRODUCT-dev-001'
param planName = 'plan-PRODUCT-dev-001'
