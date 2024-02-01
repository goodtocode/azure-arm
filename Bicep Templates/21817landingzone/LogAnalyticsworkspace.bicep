@description('Specifies the location of AKS cluster.')
param location string = resourceGroup().location

@description('Specifies the name of the Log Analytics Workspace.')
param logAnalyticsWorkspaceName string ='logAnalyticsWorkspaceName'

@allowed([
  'Free'
  'Standalone'
  'PerNode'
  'PerGB2018'
])
@description('Specifies the service tier of the workspace: Free, Standalone, PerNode, Per-GB.')
param logAnalyticsSku string = 'PerGB2018'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsSku
    }
    
  }
}

output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
