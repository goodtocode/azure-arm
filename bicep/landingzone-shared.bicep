targetScope='resourceGroup'

// Common
param tags object 
param location string
// Workspace
param workName string
param workSku string
// App Service Plan
param planName string 
param planSku string 

module workModule 'work-loganalyticsworkspace.bicep' = {
  name: 'logAnalyticsWorkspaceName'
  params: {
    name: workName
    location: location
    tags: tags    
    sku: workSku
  }
}

module planModule 'plan-appserviceplan.bicep' = {
  name: 'appservicename'
  params: {
    name: planName
    sku: planSku
    tags: tags
    location: location    
  }
}
