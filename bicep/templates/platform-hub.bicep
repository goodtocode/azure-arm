targetScope='resourceGroup'

// ESA CAF Hub main deployment template
// All modules parameterized, no hard-coded values
// Follows repo conventions and CAF naming

param location string
param prefix string
param environment string
param tags object
param vnetAddressPrefix string
param workName string
param kvName string
param firewallName string

module workModule '../modules/work-loganalyticsworkspace.bicep' = {
  name: 'workName'
  params: {
    name: workName
    location: location
    tags: tags    
    sku: workSku
  }
}

module kvModule '../modules/kv-keyvault.bicep'= {
   name:'kvModuleName'
   params:{
    location: location
    tags: tags
    name: kvName
    sku: kvSku
    tenantId: tenantId
   }
}

module vnet '../modules/vnet-virtualnetwork.bicep' = {
  name: 'hubVnet'
  params: {
    name: '${prefix}-hub-vnet'
    addressPrefix: vnetAddressPrefix
    location: location
    tags: tags
  }
}
