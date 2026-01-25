
targetScope = 'resourceGroup'

param tenantId string = tenant().tenantId
param location string = resourceGroup().location
param tags object

param mgmtSubscriptionId string = subscription().subscriptionId
param mgmtResourceGroupName string
param workName string
param appiName string

param kvName string
param kvSku string

param appcsName string
param appcsSku string = 'free'

resource workResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workName 
  scope: resourceGroup(mgmtSubscriptionId, mgmtResourceGroupName)
}

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: 'appiName'
  params:{
    location: location
    tags: tags
    name: appiName
    workResourceId: workResource.id
  }
}

module kvModule '../modules/kv-keyvault.bicep' = {
  name: 'kvName'
  params: {
    location: location
    tags: tags
    name: kvName
    sku: kvSku
    tenantId: tenantId
  }
} 

module appcsModule '../modules/appcs-appconfigurationstore.bicep' = {
  name: 'appcsName'
  params: {
    name: appcsName
    sku: appcsSku
    location: location
  }
}


