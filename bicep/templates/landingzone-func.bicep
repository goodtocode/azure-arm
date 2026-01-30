targetScope='resourceGroup'

// Common
param location string = resourceGroup().location
param tags object 
param environmentApp string 
param spokeMgmtSubscriptionId string = subscription().subscriptionId
param spokeMgmtResourceGroupName string
// Azure Monitor
param appiName string 
// Storage Account
param stName string 
param stSku string 
// function
param funcName string
param planName string
param alwaysOn bool = false

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module stModule '../modules/st-storageaccount.bicep' = {
  name:'stModuleName'
  params:{
    tags: tags
    location: location
    name: stName
    sku: stSku
  }
}

module funcModule '../modules/func-functionsapp.bicep' = {
  name: 'funcModuleName'
  params:{
    name: funcName
    location: location    
    tags: tags
    environmentApp: environmentApp
    appiKey: appiResource.properties.InstrumentationKey
    appiConnection: appiResource.properties.ConnectionString
    planId: planResource.id
    stName: stName
    alwaysOn: alwaysOn
  }
}
