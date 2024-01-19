@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Tags to add to the resources')
param tags string = 'tags'

@description('Application Insights resource name')
param applicationInsightsName string = 'applicationInsightsName'

param Application_Type string = 'web'

param Flow_Type string = 'Bluefield'

resource existingloganalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name:'existingloganalytics'
  scope: resourceGroup('Subscriptionid','shared resourcegrpname')
}


resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags:{
    '${tags}': tags
  }
  kind:'web'
  properties: {
    Application_Type: Application_Type
    Flow_Type: Flow_Type
    WorkspaceResourceId: existingloganalytics.id
    
  }
}

output applicationInsightsId string = applicationInsights.id
