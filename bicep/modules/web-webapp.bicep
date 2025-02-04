param name string 
param location string 
param tags object
param environment string 
param appiKey string
param appiConnection string
param planId string
@allowed(['api', 'app', 'app,linux', 'functionapp', 'functionapp,linux'])
param kind string = 'app'
@allowed(['v4.8', 'v6.0', 'v7.0', 'v8.0', 'v9.0'])
param dotnetVersion string = 'v8.0'

resource webAppResource 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  kind: kind
  tags: tags
  properties: {
    serverFarmId: planId
    siteConfig: {
      netFrameworkVersion: dotnetVersion
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appiKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appiConnection
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environment
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

output id string = webAppResource.id
