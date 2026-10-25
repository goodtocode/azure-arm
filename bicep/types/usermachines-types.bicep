// Component contracts for the workload-usermachines archetype
// (user VMs, developer machines, VDI-style desktops).
// Import with: import { machineConfig, ownNetworkConfig, subnetRef } from '../types/usermachines-types.bicep'

@export()
@description('Deployment mode for user machines. standalone = own VNet in the home RG. network = join an existing VNet subnet. (zerotrust uses the workload-usermachines-zerotrust template; shared is not offered because a VM always needs a subnet.)')
type userMachinesMode = 'standalone' | 'network'

@export()
@description('One user machine.')
@sealed()
type machineConfig = {
  @minLength(1)
  @maxLength(56)
  @description('Virtual machine resource name.')
  name: string

  @minLength(1)
  @maxLength(15)
  @description('Guest computer name (max 15 characters).')
  computerName: string

  @minLength(1)
  @description('VM size, for example Standard_D2s_v5.')
  size: string

  @description('Guest operating system image.')
  os: 'Windows11' | 'Windows10' | 'WindowsServer2022' | 'Ubuntu2204'

  @description('OS disk SKU.')
  osDiskSku: ('Standard_LRS' | 'StandardSSD_LRS' | 'Premium_LRS')?

  @description('Attach a public IP. Standalone mode only; ignored elsewhere.')
  publicIp: bool?
}

@export()
@description('VNet created in the home RG in standalone mode.')
@sealed()
type ownNetworkConfig = {
  @minLength(2)
  @maxLength(58)
  @description('VNet name.')
  vnetName: string

  @minLength(9)
  @maxLength(18)
  @description('VNet address space, for example 10.50.0.0/16.')
  vnetCidr: string

  @minLength(1)
  @maxLength(58)
  @description('Subnet name for the machines.')
  subnetName: string

  @minLength(9)
  @maxLength(18)
  @description('Subnet prefix, for example 10.50.1.0/24.')
  subnetCidr: string

  @description('Source CIDR allowed to reach RDP/SSH on machines with a public IP. Omit to allow no inbound.')
  allowedAdminCidr: string?
}

@export()
@description('Existing subnet the machines attach to in network and zerotrust modes.')
@sealed()
type subnetRef = {
  @description('Subscription of the VNet. Defaults to the current subscription.')
  subscriptionId: string?

  @minLength(1)
  @maxLength(90)
  @description('Resource group of the VNet.')
  resourceGroupName: string

  @minLength(2)
  @maxLength(64)
  @description('Name of the VNet.')
  vnetName: string

  @minLength(1)
  @maxLength(80)
  @description('Name of the subnet.')
  subnetName: string
}
