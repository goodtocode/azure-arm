param name string
param type string = 'web'
param tagsArray object = {}
param requestSource string = 'IbizaAIExtension'
param workName string

var workspaceResourceId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/microsoft.operationalinsights/workspaces/${workName}'

resource name_resource 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: resourceGroup().location
  tags: tagsArray
  properties: {
    ApplicationId: name
    Application_Type: type
    Flow_Type: 'Redfield'
    Request_Source: requestSource
    WorkspaceResourceId: workspaceResourceId
  }
  dependsOn: []
}
