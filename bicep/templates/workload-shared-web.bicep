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

resource appiResource 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appiName
}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: planName
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
  }
}
