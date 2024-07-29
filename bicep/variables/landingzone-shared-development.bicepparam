using '../templates/landingzone-shared.bicep'

// Common
param location = 'West US 2'
param tags = { Environment: 'dev', CostCenter: '0000' }

// Workspace
param workName = 'work-SHARED-dev-001'
param workSku = 'PerGB2018'

// App Service
param planName = 'plan-PRODUCT-dev-001'
param planSku = 'B1'
