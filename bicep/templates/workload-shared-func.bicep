targetScope = 'resourceGroup'

@description('The Azure region where resources will be deployed.')
@allowed([
  'eastus'
  'eastus2'
  'centralus'
  'northcentralus'
  'southcentralus'
  'westus'
  'westus2'
  'westus3'
  'westcentralus'
])
param location string = 'eastus'

@description('Resource tags to be applied to resources installed in the home resource group.')
param tags object

@description('Environment name for the Function App.')
@minLength(1)
@maxLength(40)
param environmentApp string

@description('Subscription ID containing the existing Application Insights resource.')
@minLength(1)
@maxLength(64)
param appiSubscriptionId string = subscription().subscriptionId

@description('Resource group containing the existing Application Insights resource.')
@minLength(1)
@maxLength(90)
param appiResourceGroupName string

@description('Name of the existing Application Insights resource.')
@minLength(1)
@maxLength(255)
param appiName string

@description('Subscription ID containing the existing App Service Plan.')
@minLength(1)
@maxLength(64)
param planSubscriptionId string = subscription().subscriptionId

@description('Resource group containing the existing App Service Plan.')
@minLength(1)
@maxLength(90)
param planResourceGroupName string

@description('Name of the existing App Service Plan.')
@minLength(1)
@maxLength(40)
param planName string

@description('Name of the Storage Account used by the Function App in the home resource group. When deployStorage is false, the account must already exist.')
@minLength(3)
@maxLength(24)
param stAccountName string

@description('Deploy the Storage Account into the current home resource group. Set to false when reusing an existing home-RG Storage Account.')
param deployStorage bool = false

@description('SKU for the optional home-RG Storage Account.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
param stSku string = 'Standard_LRS'

@description('Name of the Function App installed in the current home resource group.')
@minLength(1)
@maxLength(60)
param funcName string

@description('Enable Always On for the Function App.')
param alwaysOn bool = false

@description('Whether to use a 32-bit worker process.')
param use32BitWorkerProcess bool = true

@description('Function runtime. Allowed values: dotnet, python, dotnet-isolated.')
@allowed([
  'dotnet'
  'python'
  'dotnet-isolated'
])
param funcRuntime string = 'dotnet'

@description('Azure Functions runtime version.')
@allowed([
  1
  2
  3
  4
])
param funcVersion int = 4

@description('Integrate the Function App with an existing subnet. Set to false to skip VNet integration entirely.')
param deployToVnet bool = false

@description('Subscription ID containing the existing virtual network. Defaults to the current subscription.')
@minLength(1)
@maxLength(64)
param vnetSubscriptionId string = subscription().subscriptionId

@description('Resource group containing the existing virtual network.')
@minLength(1)
@maxLength(90)
param vnetResourceGroupName string = resourceGroup().name

@description('Name of the existing virtual network.')
param vnetName string = ''

@description('Name of the existing subnet, delegated to Microsoft.Web/serverFarms, to integrate the Function App with.')
param subnetName string = ''

@description('Route all outbound traffic through the VNet integration.')
param vnetRouteAllEnabled bool = false

@description('Route container image pull traffic through the VNet integration.')
param vnetImagePullEnabled bool = false

@description('Route content storage traffic through the VNet integration.')
param vnetContentShareEnabled bool = false

@description('Route backup/restore traffic through the VNet integration.')
param vnetBackupRestoreEnabled bool = false

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName
  scope: resourceGroup(appiSubscriptionId, appiResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName
  scope: resourceGroup(planSubscriptionId, planResourceGroupName)
}

resource subnetResource 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = if (deployToVnet) {
  name: '${vnetName}/${subnetName}'
  scope: resourceGroup(vnetSubscriptionId, vnetResourceGroupName)
}

module storageModule '../modules/st-storageaccount.bicep' = if (deployStorage) {
  name: 'storageModule'
  params: {
    location: location
    tags: tags
    name: stAccountName
    sku: stSku
  }
}

module funcModule '../modules/func-functionsapp.bicep' = {
  name: 'funcModule'
  params: {
    name: funcName
    location: location
    tags: tags
    environmentApp: environmentApp
    appiKey: appiResource.properties.InstrumentationKey
    appiConnection: appiResource.properties.ConnectionString
    planId: planResource.id
    stName: stAccountName
    stSubscriptionId: subscription().subscriptionId
    stResourceGroupName: resourceGroup().name
    use32BitWorkerProcess: use32BitWorkerProcess
    funcRuntime: funcRuntime
    funcVersion: funcVersion
    alwaysOn: alwaysOn
    subnetId: deployToVnet ? subnetResource.id : ''
    vnetRouteAllEnabled: vnetRouteAllEnabled
    vnetImagePullEnabled: vnetImagePullEnabled
    vnetContentShareEnabled: vnetContentShareEnabled
    vnetBackupRestoreEnabled: vnetBackupRestoreEnabled
  }
  // Ensure the storage account finishes provisioning before the Function App configures it.
  dependsOn: deployStorage ? [storageModule] : []
}
