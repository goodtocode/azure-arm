param name string

@description('Specifies the Azure location where the app configuration store should be created.')
param location string = toLower(replace(resourceGroup().location, ' ', ''))
param sku string
param tags object

resource name_resource 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: sku
    }
  }
}
