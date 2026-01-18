

@description('The name of the App Service Plan. Must be 1-40 characters, using only alphanumeric characters and hyphens.')
@minLength(1)
@maxLength(40)
param name string

@description('The Azure region where the App Service Plan will be deployed.')
param location string

@description('The SKU (pricing tier) for the App Service Plan. Allowed values: F1, D1, B1, B2, B3, S1, S2, S3, P1, P2, P3, P4, Y1. Default is F1.')
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

@description('Tags to apply to the App Service Plan resource.')
param tags object = {}

resource planResource 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: name
  kind:'Windows'
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    reserved: false    
  }
  sku: {
    name: sku
  }
 
}

output id string = planResource.id
