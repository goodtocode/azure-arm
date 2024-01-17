@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('The name of the app to create.')
param appName string = 'appName'

param appiKey string = 'appiKey'

param appiConnection string = 'appiConnection'

param rgEnvironment string = 'Development'

resource existingserviceplan 'Microsoft.Web/serverfarms@2023-01-01' existing ={
  name: 'existingserviceplan'
  scope:resourceGroup('Subscriptionid','shared resourcegrpname')
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: appName
  location: location
  kind: 'app'
  properties: {
    serverFarmId: existingserviceplan.id
    siteConfig: {
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
          value: rgEnvironment
        }
      ]
    }
  }
}
