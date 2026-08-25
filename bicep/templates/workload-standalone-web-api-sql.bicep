targetScope = 'resourceGroup'

@description('The Azure region where resources will be deployed. Only allowed regions for SQL module.')
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

@minLength(4)
@maxLength(63)
@description('Specifies the name of the Log Analytics workspace. 4-63 characters, letters, numbers, and -')
param workName string

@allowed(['PerGB2018', 'Free'])
@description('SKU for the Log Analytics workspace. Allowed: PerGB2018, Free.')
param workSku string = 'PerGB2018'

@minLength(1)
@maxLength(255)
@description('Specifies the name of the Application Insights resource. 1-255 characters, letters, numbers, and -')
param appiName string

@allowed(['F1', 'B1', 'B2', 'B3', 'D1', 'P1', 'P2', 'P3', 'P4', 'S1', 'S2', 'S3', 'Y1'])
@description('SKU for the App Service Plan. Allowed: F1, B1, B2, B3, D1, P1, P2, P3, P4, S1, S2, S3, Y1.')
param planSku string = 'F1'

@minLength(1)
@maxLength(40)
@description('Name of the App Service Plan. 1-40 characters.')
param planName string

@minLength(1)
@maxLength(40)
@description('Environment name for the application. 1-40 characters.')
param environmentApp string

@minLength(1)
@maxLength(60)
@description('Name of the Web App. 1-60 characters.')
param webName string

@minLength(1)
@maxLength(60)
@description('Name of the API App. 1-60 characters.')
param apiName string

@minLength(1)
@maxLength(60)
@description('Name of the SQL Server. 1-60 characters.')
param sqlName string

@minLength(1)
@maxLength(60)
@description('SQL Server admin username. 1-60 characters.')
param sqlAdminUser string

@secure()
@minLength(8)
@maxLength(60)
@description('SQL Server admin password. 8-60 characters.')
param sqlAdminPassword string

@minLength(1)
@maxLength(60)
@description('Name of the SQL Database. 1-60 characters.')
param sqldbName string

@allowed(['Basic', 'Premium', 'Standard'])
@description('SKU for the SQL Database. Allowed: Basic, Premium, Standard.')
param sqldbSku string = 'Basic'

@description('Integrate the Web App and API App with an existing subnet. Set to false to skip VNet integration entirely.')
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

@description('Name of the existing subnet, delegated to Microsoft.Web/serverFarms, to integrate the Web App and API App with.')
param subnetName string = ''

@description('Route all outbound traffic through the VNet integration.')
param vnetRouteAllEnabled bool = false

@description('Route container image pull traffic through the VNet integration.')
param vnetImagePullEnabled bool = false

@description('Route content storage traffic through the VNet integration.')
param vnetContentShareEnabled bool = false

@description('Route backup/restore traffic through the VNet integration.')
param vnetBackupRestoreEnabled bool = false

module workModule '../modules/sent-loganalyticsworkspace.bicep' = {
  name: 'workName'
  params: {
    name: workName
    location: location
    tags: tags
    sku: workSku
  }
}

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: 'appiName'
  params:{
    location: location
    tags: tags
    name: appiName
    workResourceId: workModule.outputs.id
  }
}

module planModule '../modules/plan-appserviceplan.bicep' = {
  name: 'planModule'
  params: {
    name: planName
    sku: planSku
    location: location
  }
}

resource subnetResource 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = if (deployToVnet) {
  name: '${vnetName}/${subnetName}'
  scope: resourceGroup(vnetSubscriptionId, vnetResourceGroupName)
}

module apiModule '../modules/api-appservice.bicep' = {
  name: 'apiModuleName'
  params:{
    name: apiName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiModule.outputs.InstrumentationKey
    appiConnection:appiModule.outputs.Connectionstring
    planId: planModule.outputs.id  
    subnetId: deployToVnet ? subnetResource.id : ''
    vnetRouteAllEnabled: vnetRouteAllEnabled
    vnetImagePullEnabled: vnetImagePullEnabled
    vnetContentShareEnabled: vnetContentShareEnabled
    vnetBackupRestoreEnabled: vnetBackupRestoreEnabled
  }
}

module webModule '../modules/web-appservice.bicep' = {
  name: 'webModuleName'
  params:{
    name: webName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiModule.outputs.InstrumentationKey
    appiConnection:appiModule.outputs.Connectionstring
    planId: planModule.outputs.id  
    subnetId: deployToVnet ? subnetResource.id : ''
    vnetRouteAllEnabled: vnetRouteAllEnabled
    vnetImagePullEnabled: vnetImagePullEnabled
    vnetContentShareEnabled: vnetContentShareEnabled
    vnetBackupRestoreEnabled: vnetBackupRestoreEnabled
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
