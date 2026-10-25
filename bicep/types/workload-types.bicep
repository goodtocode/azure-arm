// Shared contract for every workload-<archetype> template.
// Import with: import { workloadMode, sharedRef, vnetRef } from '../types/workload-types.bicep'

@export()
@description('Deployment mode. standalone = everything in the home RG. shared = reuse the plan and App Insights from a shared RG. network = shared + VNet integration. (zerotrust uses the workload-<archetype>-zerotrust template.)')
type workloadMode = 'standalone' | 'shared' | 'network'

@export()
@description('Azure regions supported by every component a digital product can deploy.')
type workloadRegion = 'eastus' | 'eastus2' | 'centralus' | 'westus' | 'westus2'

@export()
@description('App Service Plan SKUs.')
type planSku = 'F1' | 'B1' | 'B2' | 'B3' | 'D1' | 'P1' | 'P2' | 'P3' | 'P4' | 'S1' | 'S2' | 'S3' | 'Y1'

@export()
@description('Storage account SKUs.')
type storageSku = 'Standard_LRS' | 'Standard_GRS' | 'Standard_RAGRS' | 'Standard_ZRS' | 'Premium_LRS'

@export()
@description('Location of the shared App Service Plan and Application Insights consumed in shared and network modes. Both must be in the same subscription as the workload.')
@sealed()
type sharedRef = {
  @description('Subscription of the shared resource group. Defaults to the current subscription.')
  subscriptionId: string?

  @minLength(1)
  @maxLength(90)
  @description('Resource group that already contains the plan and Application Insights.')
  resourceGroupName: string
}

@export()
@description('Existing VNet subnet used for regional VNet integration in network mode.')
@sealed()
type vnetRef = {
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
  @description('Subnet delegated to Microsoft.Web/serverFarms. Needs the Microsoft.Storage service endpoint when a Function App is deployed.')
  subnetName: string

  @description('Route all outbound traffic through the VNet integration.')
  routeAllEnabled: bool?

  @description('Route container image pull traffic through the VNet integration.')
  imagePullEnabled: bool?

  @description('Route content share traffic through the VNet integration.')
  contentShareEnabled: bool?

  @description('Route backup and restore traffic through the VNet integration.')
  backupRestoreEnabled: bool?
}
