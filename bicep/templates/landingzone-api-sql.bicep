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

@description('Name of the App Service.')
@minLength(1)
@maxLength(60)
param appName string

@description('Name of the SQL Server.')
@minLength(1)
@maxLength(60)
param sqlName string

@description('SQL Server admin username.')
@minLength(1)
@maxLength(60)
param sqlAdminUser string

@secure()
@description('SQL Server admin password.')
@minLength(8)
@maxLength(60)
param sqlAdminPassword string

@description('Name of the SQL Database.')
@minLength(1)
@maxLength(60)
param sqldbName string

@description('SKU for the SQL Database.')
@allowed(['Basic', 'Premium', 'Standard'])
param sqldbSku string = 'Basic'

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(spokeMgmtSubscriptionId, spokeMgmtResourceGroupName)
}

module apiModule '../modules/api-appservice.bicep' = {
  name: 'apiModuleName'
  params:{
    name: appName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey: appiResource.properties.InstrumentationKey
    appiConnection: appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}

module sqlModule '../modules/sql-sqlserverdatabase.bicep' = {
  name: 'sqlModuleName'
  params:{
    name: sqlName
    location: location    
    tags: tags    
    adminLogin: sqlAdminUser
    adminPassword: sqlAdminPassword
    sqldbName: sqldbName
    sku: sqldbSku
  }
}
