targetScope='resourceGroup'

@description('The Azure region where resources will be deployed. Only US regions are allowed.')
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

@description('Resource tags to be applied to all resources.')
param tags object

@description('Environment name for the application.')
@minLength(1)
@maxLength(40)
param environmentApp string

@description('The subscription ID for the spoke management resource group.')
@minLength(1)
@maxLength(64)
param spokeMgmtSubscriptionId string = subscription().subscriptionId

@description('The resource group name for spoke management.')
@minLength(1)
@maxLength(90)
param spokeMgmtResourceGroupName string

@description('Specifies the name of the Application Insights resource.')
@minLength(1)
@maxLength(60)
param appiName string

@description('Name of the Storage Account.')
@minLength(3)
@maxLength(24)
param stName string

@description('SKU for the Storage Account.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS'])
param stSku string = 'Standard_LRS'

@description('Name of the Function App.')
@minLength(1)
@maxLength(60)
param funcName string

@description('Name of the App Service Plan.')
@minLength(1)
@maxLength(40)
param planName string

@description('Enable Always On for the Function App.')
param alwaysOn bool = false

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module stModule '../modules/st-storageaccount.bicep' = {
  name:'stModuleName'
  params:{
    tags: tags
    location: location
    name: stName
    sku: stSku
  }
}

module funcModule '../modules/func-functionsapp.bicep' = {
  name: 'funcModuleName'
  params:{
    name: funcName
    location: location    
    tags: tags
    environmentApp: environmentApp
    appiKey: appiResource.properties.InstrumentationKey
    appiConnection: appiResource.properties.ConnectionString
    planId: planResource.id
    stName: stName
    alwaysOn: alwaysOn
  }
}
