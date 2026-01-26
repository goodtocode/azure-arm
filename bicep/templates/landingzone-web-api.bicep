targetScope='resourceGroup'

// Common
param location string = resourceGroup().location
param spokeMgmtSubscriptionId string = subscription().subscriptionId
param spokeMgmtResourceGroupName string
param hubMgmtSubscriptionId string
param hubMgmtResourceGroupName string
param environmentApp string 
param tags object
// Azure Monitor
param appiName string 
// App Service
param planName string 
param webName string 
param apiName string 

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(hubMgmtSubscriptionId, hubMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module apiModule '../modules/api-appservice.bicep' = {
  name: 'apiModuleName'
  params:{
    name: apiName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiResource.properties.InstrumentationKey
    appiConnection:appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}

module webModule '../modules/web-appservice.bicep' = {
  name: 'webModuleName'
  params:{
    name: webName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiResource.properties.InstrumentationKey
    appiConnection:appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}
