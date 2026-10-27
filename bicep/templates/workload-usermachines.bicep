// =============================================================================
// workload-usermachines
// Archetype : User machines (VMs for people: developer boxes, desktops, VDI-style)
//             Not a digital product. For web/API/SQL/Function use workload-digitalproduct.
// Modes     : standalone | network   (see README "Modes")
//   standalone - own VNet, subnet and NSG in this RG. Optional public IP per machine.
//   network    - machines join an existing subnet (spoke VNet). Never gets a public IP.
// Zero trust (hardened, Entra login, no public IP) lives in workload-usermachines-zerotrust.
// Variables : bicep/variables/workload-usermachines-<mode>-<env>.bicepparam
// =============================================================================
targetScope = 'resourceGroup'

import { workloadRegion } from '../types/workload-types.bicep'
import { userMachinesMode, machineConfig, ownNetworkConfig, subnetRef } from '../types/usermachines-types.bicep'

@description('Deployment mode. standalone or network.')
param mode userMachinesMode

@description('Azure region for all resources in this deployment.')
param location workloadRegion

@description('Resource tags applied to every resource.')
param tags object

@description('VNet, subnet and NSG created in this RG. Required when mode is standalone.')
param ownNetwork ownNetworkConfig?

@description('Existing subnet the machines join. Required when mode is network.')
param subnet subnetRef?

@minLength(1)
@description('The machines to create.')
param machines machineConfig[]

@minLength(1)
@maxLength(20)
@description('Local administrator user name.')
param adminUsername string

@secure()
@description('Local administrator password.')
param adminPassword string

var isStandalone = mode == 'standalone'
var adminRules = isStandalone && !empty(ownNetwork.?allowedAdminCidr) ? [
  {
    name: 'allow-admin-remote'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: ownNetwork!.allowedAdminCidr!
    destinationAddressPrefix: '*'
  }
] : []

module vnetModule '../modules/vnet-virtualnetwork.bicep' = if (isStandalone) {
  name: 'vnet-${ownNetwork!.vnetName}'
  params: {
    name: ownNetwork!.vnetName
    addressPrefix: ownNetwork!.vnetCidr
    location: location
    tags: tags
  }
}

module nsgModule '../modules/nsg-networksecuritygroup.bicep' = if (isStandalone) {
  name: 'nsg-${ownNetwork!.subnetName}'
  params: {
    name: '${ownNetwork!.subnetName}-nsg'
    location: location
    tags: tags
    securityRules: adminRules
  }
}

module snetModule '../modules/snet-virtualnetworksubnet.bicep' = if (isStandalone) {
  name: 'snet-${ownNetwork!.subnetName}'
  params: {
    vnetName: ownNetwork!.vnetName
    snetName: ownNetwork!.subnetName
    cidr: ownNetwork!.subnetCidr
    nsgId: nsgModule!.outputs.id
  }
  dependsOn: [
    vnetModule
  ]
}

var subnetId = isStandalone
  ? snetModule!.outputs.id
  : resourceId(subnet.?subscriptionId ?? subscription().subscriptionId, subnet!.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', subnet!.vnetName, subnet!.subnetName)

module pipModules '../modules/pip-publicipaddress.bicep' = [for m in machines: if (isStandalone && (m.?publicIp ?? false)) {
  name: 'pip-${m.name}'
  params: {
    name: '${m.name}-pip'
    location: location
    tags: tags
  }
}]

module nicModules '../modules/nic-networkinterface.bicep' = [for (m, i) in machines: {
  name: 'nic-${m.name}'
  params: {
    name: '${m.name}-nic'
    location: location
    tags: tags
    subnetId: subnetId
    publicIpId: isStandalone && (m.?publicIp ?? false) ? pipModules[i]!.outputs.id : ''
  }
}]

module vmModules '../modules/vm-virtualmachine.bicep' = [for (m, i) in machines: {
  name: 'vm-${m.name}'
  params: {
    name: m.name
    computerName: m.computerName
    location: location
    tags: tags
    size: m.size
    os: m.os
    osDiskSku: m.?osDiskSku ?? 'StandardSSD_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: nicModules[i].outputs.id
  }
}]

@description('Resource IDs of the machines, in the order supplied.')
output machineIds array = [for (m, i) in machines: vmModules[i].outputs.id]
