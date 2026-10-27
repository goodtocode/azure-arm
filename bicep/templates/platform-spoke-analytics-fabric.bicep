targetScope = 'resourceGroup'

@description('Azure region for the Fabric capacity. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to the Fabric capacity.')
param tags object

@minLength(3)
@maxLength(63)
@description('Name of the Microsoft Fabric capacity. Use lowercase letters and numbers only.')
param capacityName string

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
param capacitySkuName string = 'F2'

@minLength(1)
@description('User identities or object IDs to assign as Fabric capacity administrators.')
param capacityAdminMembers array

module fabricCapacityModule '../modules/fabric-capacity.bicep' = {
  name: 'fabricCapacityModule'
  params: {
    name: capacityName
    location: location
    tags: tags
    skuName: capacitySkuName
    adminMembers: capacityAdminMembers
  }
}

@description('Resource ID of the Microsoft Fabric capacity.')
output capacityResourceId string = fabricCapacityModule.outputs.resourceId

@description('Name of the Microsoft Fabric capacity.')
output capacityName string = fabricCapacityModule.outputs.name

@description('SKU name of the Microsoft Fabric capacity.')
output capacitySkuName string = fabricCapacityModule.outputs.skuName
