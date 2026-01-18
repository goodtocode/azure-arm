
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object

param sentName string
param sentSku string
param appiName string
param kvName string
param kvSku string


var sharedSnetSecurityRules = [
  {
    name: 'AllowVnetIn'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
  {
    name: 'DenyAllInbound'
    priority: 4096
    direction: 'Inbound'
    access: 'Deny'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: '*'
    destinationAddressPrefix: '*'
  }
]

module vnet '../modules/vnet-virtualnetwork.bicep' = {
  name: vnetName
  params: {
    name: vnetName
    addressPrefix: vnetCidr
    location: location
    tags: tags
  }
}

module nsgShared '../modules/nsg-networksecuritygroup.bicep' = {
  name: '${snetNameShared}-nsg'
  params: {
    name: '${snetNameShared}-nsg'
    tags: tags
    securityRules: sharedSnetSecurityRules
  }
}

module snetShared '../modules/snet-virtualnetworksubnet.bicep' = {
  name: snetNameShared
  params: {
    vnetName: vnetName
    snetName: snetNameShared
    cidr: snetCidrShared
    nsgId: nsgShared.outputs.id
  }
}

module snetManagement '../modules/snet-virtualnetworksubnet.bicep' = {
  name: snetNameManagement
  params: {
    vnetName: vnetName
    snetName: snetNameManagement
    cidr: snetCidrManagement
    // nsgId: <add if required>
  }
}

module sentModule '../modules/sent-loganalyticsworkspace.bicep' = {
  name: sentName
  params: {
    name: sentName
    location: location
    tags: tags
    sku: sentSku
  }
}

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: appiName
  params: {
    location: location
    tags: tags
    name: appiName
    workResourceId: sentModule.outputs.id
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
