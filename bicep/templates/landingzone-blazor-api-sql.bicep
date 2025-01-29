targetScope='resourceGroup'

// Common
param location string = resourceGroup().location
param sharedSubscriptionId string = subscription().subscriptionId
param sharedResourceGroupName string
param environmentApp string 
param tags object
// Azure Monitor
param appiName string 
// Storage Account
param stName string 
param stSku string 
// App Service
param planName string 
param webName string 
param appName string 
// Sql Server
param sqlName string 
param sqlAdminUser string
@secure()
param sqlAdminPassword string
param sqldbName string
param sqldbSku string

module stModule '../modules/st-storageaccount.bicep' = {
  name:'stModuleName'
  params:{
    tags: tags
    location: location
    name: stName
    sku: stSku
  }
}

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName 
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName 
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

module apiModule '../modules/api-appservice.bicep' = {
  name: 'apiModuleName'
  params:{
    name: appName
    location: location    
    tags: tags
    environment: environmentApp
    appiKey:appiResource.properties.InstrumentationKey
    appiConnection:appiResource.properties.ConnectionString
    planId: planResource.id  
  }
}

module webModule '../modules/web-webapp.bicep' = {
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
