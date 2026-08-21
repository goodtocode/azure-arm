targetScope = 'resourceGroup'

@description('The Azure region where resources will be deployed.')
@allowed([
  'eastus'
  'eastus2'
  'centralus'
  'westus'
  'westus2'
])
param location string = 'eastus'

@description('Resource tags to be applied to all resources.')
param tags object

@description('Subscription ID containing the existing Application Insights resource. Defaults to the deployment subscription.')
@minLength(1)
@maxLength(64)
param appiSubscriptionId string = subscription().subscriptionId

@description('Subscription ID containing the existing App Service Plan. Defaults to the deployment subscription.')
@minLength(1)
@maxLength(64)
param planSubscriptionId string = subscription().subscriptionId

@description('Resource group in the subscription containing the existing Application Insights resource.')
@minLength(1)
@maxLength(90)
param appiResourceGroupName string

@description('Resource group in the subscription containing the existing App Service Plan.')
@minLength(1)
@maxLength(90)
param planResourceGroupName string

@minLength(1)
@maxLength(255)
@description('Name of the existing Application Insights resource to wire the Web App to. 1-255 characters, letters, numbers, and -')
param appiName string

@minLength(1)
@maxLength(40)
@description('Name of the existing App Service Plan to host the Web App. 1-40 characters.')
param planName string

@minLength(1)
@maxLength(40)
@description('Environment name for the application. 1-40 characters.')
param environmentApp string

@minLength(1)
@maxLength(60)
@description('Name of the Web App. 1-60 characters.')
param webName string

@minLength(3)
@maxLength(24)
@description('Name of the optional Storage Account installed in the home resource group.')
param stAccountName string

@description('Deploy the optional Storage Account into the current home resource group.')
param deployStorage bool = false

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
])
@description('SKU for the optional home resource group Storage Account.')
param stSku string = 'Standard_LRS'

@description('Integrate the Web App with an existing subnet. Set to false to skip VNet integration entirely.')
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

@description('Name of the existing subnet, delegated to Microsoft.Web/serverFarms, to integrate the Web App with.')
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

module stModule '../modules/st-storageaccount.bicep' = if (deployStorage) {
  name: 'stModule'
  params: {
    location: location
    tags: tags
    name: stAccountName
    sku: stSku
  }
}

module webModule '../modules/web-appservice.bicep' = {
  name: 'webModuleName'
  params:{
    name: webName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey: appiResource.properties.InstrumentationKey
    appiConnection: appiResource.properties.ConnectionString
    planId: planResource.id  
    subnetId: deployToVnet ? subnetResource.id : ''
    vnetRouteAllEnabled: vnetRouteAllEnabled
    vnetImagePullEnabled: vnetImagePullEnabled
    vnetContentShareEnabled: vnetContentShareEnabled
    vnetBackupRestoreEnabled: vnetBackupRestoreEnabled
  }
}
