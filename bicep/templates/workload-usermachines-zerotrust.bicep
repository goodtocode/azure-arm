// =============================================================================
// workload-usermachines-zerotrust
// Archetype : User machines (VMs for people). Mode 4: zero trust.
// Posture   : no public IP, Trusted Launch, encryption at host, Microsoft Entra ID login.
//             Machines join an existing spoke subnet; reach them through Bastion.
// Needs     : EncryptionAtHost feature registered on the subscription; the spoke subnet
//             NSG and routing are owned by the platform repo.
// Variables : bicep/variables/workload-usermachines-zerotrust-<env>.bicepparam
// =============================================================================
targetScope = 'resourceGroup'

import { workloadRegion } from '../types/workload-types.bicep'
import { machineConfig, subnetRef } from '../types/usermachines-types.bicep'

@description('Azure region for all resources in this deployment.')
param location workloadRegion

@description('Resource tags applied to every resource.')
param tags object

@description('Existing spoke subnet the machines join.')
param subnet subnetRef

@minLength(1)
@description('The machines to create. publicIp is ignored: zero trust never attaches one.')
param machines machineConfig[]

@minLength(1)
@maxLength(20)
@description('Local administrator user name.')
param adminUsername string

@secure()
@description('Local administrator password.')
param adminPassword string

var subnetId = resourceId(subnet.?subscriptionId ?? subscription().subscriptionId, subnet.resourceGroupName, 'Microsoft.Network/virtualNetworks/subnets', subnet.vnetName, subnet.subnetName)

module nicModules '../modules/nic-networkinterface.bicep' = [for m in machines: {
  name: 'nic-${m.name}'
  params: {
    name: '${m.name}-nic'
    location: location
    tags: tags
    subnetId: subnetId
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
    osDiskSku: m.?osDiskSku ?? 'Premium_LRS'
    adminUsername: adminUsername
    adminPassword: adminPassword
    nicId: nicModules[i].outputs.id
    trustedLaunch: true
    encryptionAtHost: true
    entraLogin: true
  }
}]

@description('Resource IDs of the machines, in the order supplied.')
output machineIds array = [for (m, i) in machines: vmModules[i].outputs.id]
