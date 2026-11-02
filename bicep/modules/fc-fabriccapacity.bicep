@description('Name of the Microsoft Fabric capacity. Use lowercase letters and numbers only.')
@minLength(3)
@maxLength(63)
param name string

@description('Azure region for the Microsoft Fabric capacity.')
param location string

@description('Tags to apply to the Microsoft Fabric capacity.')
param tags object = {}

@description('Fabric capacity SKU. Allowed values are the supported Fabric capacity levels.')
@allowed([
  'F2'
  'F4'
  'F8'
  'F16'
  'F32'
  'F64'
  'F128'
  'F256'
  'F512'
  'F1024'
  'F2048'
])
param skuName string = 'F2'

@description('User identities or object IDs to assign as Fabric capacity administrators.')
@minLength(1)
param adminMembers array

resource fabricCapacity 'Microsoft.Fabric/capacities@2025-01-15-preview' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  sku: {
    name: skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: adminMembers
    }
  }
}

@description('Resource ID of the Microsoft Fabric capacity.')
output resourceId string = fabricCapacity.id

@description('Name of the Microsoft Fabric capacity.')
output name string = fabricCapacity.name

@description('SKU name of the Microsoft Fabric capacity.')
output skuName string = skuName
