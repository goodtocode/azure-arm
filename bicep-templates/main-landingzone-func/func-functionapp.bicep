param location string = resourceGroup().location
param functionappname string = 'functionappname'
param stName string = 'storageaccountname'
param appiKey string = 'appikey'
param appiConnection string = 'appiConnection'
param use32BitWorkerProcess bool = true

@allowed([
  'Development'
  'QA'
  'Staging'
  'Production'
])
param rgEnvironment string = 'Development'

@allowed([
  'dotnet'
  'python'
  'dotnet-isolated'
])
param funcRuntime string = 'dotnet'

@allowed([
  1
  2
  3
  4
])
param funcVersion int = 4

resource existingserviceplan 'Microsoft.Web/serverfarms@2023-01-01' existing ={
  name: 'existingserviceplan'
  scope:resourceGroup('Subscriptionid','shared resourcegrpname')
}

resource functionapp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionappname 
  kind: 'functionapp'
  location: location
  tags: {}
  properties: {
    serverFarmId: existingserviceplan.id
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~${funcVersion}'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: funcRuntime
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appiKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appiConnection
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${stName};AccountKey=${listKeys(resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.Storage/storageAccounts', stName), '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${stName};AccountKey=${listKeys(resourceId(subscription().subscriptionId, resourceGroup().name, 'Microsoft.Storage/storageAccounts', stName), '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionappname)
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: rgEnvironment
        }
        {
          name: 'AZURE_FUNCTIONS_ENVIRONMENT'
          value: rgEnvironment
        }
      ]
      use32BitWorkerProcess: use32BitWorkerProcess
    }
    
  }
}
