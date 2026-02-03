@description('Name of the Azure OpenAI instance. Must be globally unique and 3-63 characters, using only lowercase letters, numbers, and hyphens, starting and ending with a letter or number.')
@minLength(3)
@maxLength(63)
param name string

@description('Location for the Azure OpenAI resource.')
param location string

@description('Tags to apply to the Azure OpenAI resource.')
param tags object = {}

@description('SKU for Azure OpenAI. Allowed values: Standard, Default is Standard.')
@allowed([
  'Standard'
])
param sku string = 'Standard'

resource azoaiResource 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  properties: {
    apiProperties: {
      enableDynamicThrottling: true
    }
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

output id string =  azoaiResource.id
