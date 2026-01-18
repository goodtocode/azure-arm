
param location string 
param tags object = {}
param name string 
param workResourceId string

resource appiResource 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  kind:'web'
  properties: {
    WorkspaceResourceId: workResourceId
  }
}

output id string = appiResource.id
output InstrumentationKey string  = appiResource.properties.InstrumentationKey
output Connectionstring string = appiResource.properties.ConnectionString
