targetScope = 'resourceGroup'

param location string = resourceGroup().location
param tags object

@minLength(2)
@maxLength(64)
@description('Specifies the name of the Virtual Network. 2-64 characters, letters, numbers, and -')
param vnetName string

@minLength(9)
@maxLength(18)
@description('Specifies the address prefix (CIDR block) for the Virtual Network. Example: 10.0.0.0/16')
param vnetCidr string

@minLength(1)
@maxLength(80)
@description('Specifies the name of the management subnet. 1-80 characters, letters, numbers, and -')
param snetNameManagement string

@minLength(9)
@maxLength(18)
@description('Specifies the address prefix (CIDR block) for the management subnet. Example: 10.0.1.0/24')
param snetCidrManagement string

@maxLength(80)
@description('Name of the app integration subnet delegated to Microsoft.Web/serverFarms, used by workloads for App Service regional VNet integration. Leave empty to skip.')
param snetNameApps string = ''

@maxLength(18)
@description('Address prefix (CIDR block) for the app integration subnet. Required when snetNameApps is set. Example: 10.0.2.0/24')
param snetCidrApps string = ''

var deployApps = !empty(snetNameApps)
var platformManagementSecurityRules = [
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
  name: 'nsgNameManagement'
  params: {
    name: '${snetNameManagement}-nsg'
    tags: tags
    securityRules: platformManagementSecurityRules
  }
}

module snetHub '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetNameManagement'
  params: {
    vnetName: vnetName
    snetName: snetNameManagement
    cidr: snetCidrManagement
    nsgId: nsgSnet.outputs.id
  }
  dependsOn: [
    vnet
  ]
}

// The apps NSG has no custom rules yet, so Azure default rules apply. Add rules here (and a route table on the subnet) when the spoke is locked down.
module nsgApps '../modules/nsg-networksecuritygroup.bicep' = if (deployApps) {
  name: 'nsgNameApps'
  params: {
    name: '${snetNameApps}-nsg'
    tags: tags
    location: location
  }
}

module snetApps '../modules/snet-virtualnetworksubnet.bicep' = if (deployApps) {
  name: 'snetNameApps'
  params: {
    vnetName: vnetName
    snetName: snetNameApps
    cidr: snetCidrApps
    nsgId: nsgApps!.outputs.id
    delegation: 'Microsoft.Web/serverFarms'
    serviceEndpoints: [
      'Microsoft.Storage'
    ]
  }
  dependsOn: [
    snetHub
  ]
}

@description('Resource ID of the spoke VNet.')
output vnetId string = vnet.outputs.id

@description('Resource ID of the management subnet.')
output snetManagementId string = snetHub.outputs.id

@description('Resource ID of the app integration subnet. Empty when not deployed.')
output snetAppsId string = deployApps ? snetApps!.outputs.id : ''
