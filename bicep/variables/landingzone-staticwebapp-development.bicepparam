using '../templates/landingzone-staticwebapp.bicep'
// Common
param location = 'West US 2'
param tags = { Environment: 'dev', CostCenter: '0000' }
// Workspace
param sharedResourceGroupName = 'rg-SHARED-dev-001'
param workName = 'work-SHARED-dev-001'

// Azure Monitor
param appiName = 'appi-PRODUCT-dev-001'
param Flow_Type = 'Bluefield'
param Application_Type = 'web'

// Storage
param stName = 'stPRODUCTdev001'
param stSku = 'Standard_LRS'

// Key Vault
param kvName = 'kv-PRODUCT-dev-001'
param kvSku = 'standard'

// Static Web app
param stappName = 'stapp-PRODUCT-dev-001'
param repositoryUrl = ''
