param name string
param stName string
param workName string
param appiKey string
param appiConnection string
param use32BitWorkerProcess bool = true
param skuTier string = 'Dynamic'
param sku string = 'Y1'

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
param workerSize string = '0'
param workerSizeId string = '0'

@allowed([
  1
  2
  3
  4
])
param funcVersion int = 4
param numberOfWorkers string = '1'

var planName_var = 'plan-${name}'

resource name_resource 'Microsoft.Web/sites@2018-11-01' = {
  name: name
  kind: 'functionapp'
  location: resourceGroup().location
  tags: {}
  properties: {
    name: name
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
          value: '${toLower(name)}9711'
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
    serverFarmId: '/subscriptions/${subscription().subscriptionId}/resourcegroups/${resourceGroup().name}/providers/Microsoft.Web/serverfarms/${planName_var}'
    clientAffinityEnabled: true
  }
  dependsOn: [
    planName
  ]
}

resource planName 'Microsoft.Web/serverfarms@2018-11-01' = {
  name: planName_var
  location: resourceGroup().location
  kind: ''
  tags: {}
  properties: {
    name: planName_var
    workerSize: workerSize
    workerSizeId: workerSizeId
    numberOfWorkers: numberOfWorkers
  }
  sku: {
    Tier: skuTier
    Name: sku
  }
  dependsOn: []
}

module newWorkspaceTemplate './nested_newWorkspaceTemplate.bicep' = {
  name: 'newWorkspaceTemplate'
  scope: resourceGroup(subscription().subscriptionId, resourceGroup().name)
  params: {
    workName: workName
  }
}