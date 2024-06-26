targetScope='resourceGroup'

// Common
param tenantId string = tenant().tenantId
param location string = resourceGroup().location
param tags object
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
// workspace
param workName string
param workSku string

module workModule '../modules/work-loganalyticsworkspace.bicep' = {
  name: 'workModuleName'
  params:{
    name: workName
    location: location
    tags: tags    
    sku: workSku
  }
}

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: 'appiModuleName'
  params:{
    location: location
    tags: tags
    name: appiName
    Application_Type: Application_Type
    Flow_Type: Flow_Type
    workResourceId: workModule.outputs.id
  }
}

module kvModule '../modules/kv-keyvault.bicep'= {
   name:'kvModuleName'
   params:{
    location: location
    tags: tags
    name: keyVaultName
    sku: skuName
    tenantId: tenantId
   }
}

module stModule '../modules/st-storageaccount.bicep' = {
  name:'stModuleName'
  params:{
    tags: tags
    location: location
    name: storageName
    sku: storageSkuName
  }
}
