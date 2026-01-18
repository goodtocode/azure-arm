
@description('The name of the App Service Plan. Must be 1-40 characters, using only alphanumeric characters and hyphens.')
@minLength(1)
@maxLength(40)
param name string

@description('The SKU (pricing tier) for the App Service Plan. Allowed values: F1, D1, B1, B2, B3, S1, S2, S3, P1, P2, P3, P4, Y1. Default is F1. See https://azure.microsoft.com/en-us/pricing/details/app-service/')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
  'Y1'
])
param sku string = 'F1'

@description('The instance count (capacity) for the App Service Plan. Minimum is 1. Default is 1.')
@minValue(1)
param skuCapacity int = 1

resource name_resource 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: name
  location: resourceGroup().location
  tags: {
    displayName: 'HostingPlan'
  }
  sku: {
    name: sku
    capacity: skuCapacity
  }
}
