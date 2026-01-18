targetScope = 'resourceGroup'

// Common
param location string = resourceGroup().location
param tags object

// Networking
param afdSku string = 'Standard_AzureFrontDoor' // Required for public front door
param vnetName string
param vnetCidr string
param snetNameHubShared string
param snetCidrHubShared string
param snetNameAzureBastion string
param snetCidrAzureBastion string


//
// Networking
//
// Bastion subnet - typically locked down, only Bastion management ports allowed
var bastionSecurityRules = [
  {
    name: 'AllowBastionGateway'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'GatewayManager'
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

// Platform Shared Services subnet - allow internal platform traffic, block others
var platformSharedSecurityRules = [
  {
    name: 'AllowPlatformHTTP'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '80'
    sourceAddressPrefix: 'VirtualNetwork'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowPlatformHTTPS'
    priority: 110
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
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
  name: 'vnetName'
  params: {
    name: vnetName
    addressPrefix: vnetCidr
    location: location
    tags: tags
  }
}

module nsgSnet '../modules/nsg-networksecuritygroup.bicep' = {
  name: 'nsgNameHubShared'
  params: {
    name: '${snetNameHubShared}-nsg'
    tags: tags
    securityRules: platformSharedSecurityRules
  }
}

module snetHub '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetNameHubShared'
  params: {
    vnetName: vnetName
    snetName: snetNameHubShared
    cidr: snetCidrHubShared
    nsgId: nsgSnet.outputs.id
  }
}

module nsgBastion '../modules/nsg-networksecuritygroup.bicep' = {
  name: 'nsgNameAzureBastion'
  params: {
    name: '${snetNameAzureBastion}-nsg'
    tags: tags
    securityRules: bastionSecurityRules
  }
}

module snetBastion '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetNameAzureBastion'
  params: {
    vnetName: vnetName
    snetName: snetNameAzureBastion
    cidr: snetCidrAzureBastion
    nsgId: nsgBastion.outputs.id
  }
}

module afd '../modules/afd-azurefrontdoor.bicep' = {
  name: 'afdName'
  params: {
    name: '${vnetName}-afd'
    location: 'global'
    tags: tags
    sku: afdSku
  }
}
