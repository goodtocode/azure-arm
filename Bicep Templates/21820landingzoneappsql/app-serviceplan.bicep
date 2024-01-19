param location string = resourceGroup().location

param appServicePlanName string = 'appServicePlanName'
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

param tags string = 'tags'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  tags:{
    '${tags}': tags
  }
  properties: {
    reserved: true
  }
  sku: {
    name: sku
  }
}
