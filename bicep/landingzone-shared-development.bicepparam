using 'landingzone-shared.bicep'

// Common
param location = 'West US 2'
param tags = { Environment: 'prod', CostCenter: '1111' }

// Workspace
param workName = 'work-SHARED-dev-001'
param workSku = 'PerGB2018'

// App Service
param planName = 'plan-PRODUCT-dev-001'
param planSku = 'S1'
