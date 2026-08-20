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

@description('The subscription ID for the spoke management resource group.')
@minLength(1)
@maxLength(64)
param spokeMgmtSubscriptionId string = subscription().subscriptionId

@description('The resource group name for spoke management.')
@minLength(1)
@maxLength(90)
param spokeMgmtResourceGroupName string

@description('The subscription ID for the hub management resource group.')
@minLength(1)
@maxLength(64)
param hubMgmtSubscriptionId string

@description('The resource group name for hub management.')
@minLength(1)
@maxLength(90)
param hubMgmtResourceGroupName string

@description('Environment name for the application.')
@minLength(1)
@maxLength(40)
param environmentApp string

@description('Resource tags to be applied to all resources.')
param tags object

@description('Specifies the name of the Application Insights resource.')
@minLength(1)
@maxLength(60)
param appiName string

@description('Name of the App Service Plan.')
@minLength(1)
@maxLength(40)
param planName string

@description('Name of the Web App.')
@minLength(1)
@maxLength(60)
param webName string

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(hubMgmtSubscriptionId, hubMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module webModule '../modules/web-appservice.bicep' = {
  name: 'webModuleName'
  params:{
    name: webName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiResource.properties.InstrumentationKey
    appiConnection:appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}
