targetScope='resourceGroup'

// Common
param tenantId string = tenant().tenantId
param location string = resourceGroup().location
param tags object

// Identity
param kvName string
param kvSku string
param sentName string
param sentSku string

// Networking
var afdName string = '' // Purposely want it to default
param afdSku string = 'Standard_AzureFrontDoor'
param vnetName string
param vnetCidr string
param snetName string
param snetCidr string

module sentModule '../modules/sent-loganalyticsworkspace.bicep' = {
  name: 'sentName'
  params: {
    name: sentName
    location: location
    tags: tags    
    sku: sentSku
  }
}

module kvModule '../modules/kv-keyvault.bicep'= {
   name:'kvName'
   params:{
    location: location
    tags: tags
    name: kvName
    sku: kvSku
    tenantId: tenantId
   }
}

module vnet '../modules/vnet-virtualnetwork.bicep' = {
  name: 'vnetName'
  params: {
    name: vnetName
    addressPrefix: vnetCidr
    location: location
    tags: tags
  }
}

module snet '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetName'
  params: {
    vnetName: vnetName
    snetName: snetName
    cidr: snetCidr
  }
}

module afd '../modules/afd-azurefrontdoor.bicep' = {
  name: 'afdName'
  params: {
    name: empty(afdName) ? '${vnetName}-afd' : afdName
    location: 'global'
    tags: tags
    sku: afdSku
  }
}
