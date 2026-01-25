targetScope='resourceGroup'

// Common
param location string = resourceGroup().location
param spokeMgmtSubscriptionId string = subscription().subscriptionId
param spokeMgmtResourceGroupName string
param environmentApp string 
param tags object
// Azure Monitor
param appiName string 
// App Service
param planName string 
param appName string 

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module apiModule '../modules/api-appservice.bicep' = {
  name: 'apiModuleName'
  params:{
    name: appName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiResource.properties.InstrumentationKey
    appiConnection:appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}
