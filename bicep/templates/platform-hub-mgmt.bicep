targetScope = 'resourceGroup'

// Common
param tenantId string = tenant().tenantId
param location string = resourceGroup().location
param tags object

// Management
@minLength(4)
@maxLength(63)
@description('Specifies the name of the Log Analytics workspace. 4-63 characters, letters, numbers, and -')
param sentName string

@minLength(4)
@maxLength(20)
@description('Specifies the SKU for the Log Analytics workspace. Allowed values: Free, PerGB2018, CapacityReservation.')
@allowed([
  'Free'
  'PerGB2018'
  'CapacityReservation'
])
param sentSku string

@minLength(1)
@maxLength(255)
@description('Specifies the name of the Application Insights resource. 1-255 characters, letters, numbers, and -')
param appiName string

@minLength(3)
@maxLength(24)
@description('Specifies the Key Vault name. 3-24 characters, letters, numbers, and -')
param kvName string

@minLength(7)
@maxLength(8)
@description('Specifies the SKU for the Key Vault. Allowed values: standard, premium.')
@allowed([
  'standard'
  'premium'
])
param kvSku string

//
// Management
//
module sentModule '../modules/sent-loganalyticsworkspace.bicep' = {
  name: 'sentName'
  params: {
    name: sentName
    location: location
    tags: tags
    sku: sentSku
  }
}

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: 'appiName'
  params:{
    location: location
    tags: tags
    name: appiName
    workResourceId: sentModule.outputs.id
  }
}

module kvModule '../modules/kv-keyvault.bicep' = {
  name: 'kvName'
  params: {
    location: location
    tags: tags
    name: kvName
    sku: kvSku
    tenantId: tenantId
  }
} 
