targetScope='resourceGroup'

// Common
param tenantId string 
param location string 
param tags object 
param rgEnvironment string 
param sharedSubscriptionId string
param sharedResourceGroupName string
// Azure Monitor
param appiName string 
param Application_Type string 
param Flow_Type string 
// Key Vault
param keyVaultName string 
param skuName string 
// Storage Account
param storageName string 
param storageSkuName string 
// App Service
param planName string 
param appName string 
// workspace
param workName string

resource workResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workName 
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

module appiModule 'appi-applicationinsights.bicep' = {
  name: 'appiName'
  params:{
    location: location
    tags: tags
    name: appiName
    Application_Type: Application_Type
    Flow_Type: Flow_Type
    workResourceId: workResource.id
  }
}

module kvModule 'kv-keyvault.bicep'= {
   name:'keyVaultName'
   params:{
    location: location
    tags: tags
    name: keyVaultName
    sku: skuName
    tenantId: tenantId
   }
}

module stModule 'st-storageaccount.bicep' = {
  name:'storagename'
  params:{
    tags: tags
    location: location
    storageName: storageName
    storageSkuName: storageSkuName
  }
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

module apiModule 'api-appservice.bicep' = {
  name: 'app'
  params:{
    name: appName
    location: location    
    tags: tags
    environment: rgEnvironment
    appiKey:appiModule.outputs.InstrumentationKey
    appiConnection:appiModule.outputs.Connectionstring
    planId: planResource.id  
  }
}
