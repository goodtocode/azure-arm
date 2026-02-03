targetScope = 'resourceGroup'

@description('Azure region for resource deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to resources. Must be an object.')
param tags object

@minLength(3)
@maxLength(63)
@description('Name of the Azure OpenAI instance. Must be globally unique, 3-63 characters, using only lowercase letters, numbers, and hyphens, starting and ending with a letter or number.')
param azoaiName string

@allowed([
  'S0'
])
@description('SKU for Azure OpenAI. Allowed value: S0. Defaults to S0.')
param azoaiSku string = 'S0'

module azoaiModule '../modules/azoai-azureopenai.bicep' = {
  name: 'azoaiModule'
  params: {
    name: azoaiName
    sku: azoaiSku
    location: location
    tags: tags    
    }
  }
