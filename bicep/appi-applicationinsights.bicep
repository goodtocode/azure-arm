@description('Application Insights resource name')
param name string = 'applicationInsightsName'

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Tags to add to the resources')
param tagsArray object = {}

@description('Type of application insights')
param type string = 'web'

@description('Kind of the Storage Account.')
@allowed([  
  'Bluefield'
  'Redfield'
])
param flow string = 'Bluefield'
param requestSource string = 'IbizaAIExtension'
@description('Workspace Resource name')
param workName string
@description('Workspace Resource Group')
param workSubscriptionId string = subscription().subscriptionId
@description('Workspace Resource Group')
param workResourceGroupName string = resourceGroup().name

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: tagsArray
  kind: type
  properties: {
    Application_Type: type
    Flow_Type: flow
    Request_Source: requestSource
    WorkspaceResourceId: resourceId(workSubscriptionId, workResourceGroupName, 'Microsoft.OperationalInsights/workspaces', workName)    
  }
}

output applicationInsightsId string = applicationInsights.id
