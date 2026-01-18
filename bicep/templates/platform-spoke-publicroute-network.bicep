
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object
param vnetName string
param vnetCidr string
param snetNameShared string
param snetCidrShared string
param snetNameManagement string
param snetCidrManagement string


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

// If DNS Private Zone is needed for the spoke, add the resource block below:
// module dnsPrivateZone '../modules/dns-privatezone.bicep' = {
//   name: 'dnsPrivateZoneName'
//   params: {
//     // ... DNS Private Zone configuration ...
//   }
// }
