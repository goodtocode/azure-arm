param name string

@description('Specifies the Azure location where the app configuration store should be created.')
param location string = resourceGroup().location

@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
@description('Specifies the service tier of the workspace: Free, Standalone, PerNode, Per-GB.')
param sku string = 'PerGB2018'

@description('Tags to add to the resources')
param tags object = {}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
