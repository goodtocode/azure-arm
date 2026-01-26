
param location string 
param tags object = {}
@description('Specifies the name of the Application Insights resource. 1-255 characters, letters, numbers, and -')
@minLength(1)
@maxLength(255)
param name string 
param workResourceId string

resource appiResource 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  kind:'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    WorkspaceResourceId: workResourceId
  }
}

output id string = appiResource.id
output InstrumentationKey string  = appiResource.properties.InstrumentationKey
output Connectionstring string = appiResource.properties.ConnectionString
