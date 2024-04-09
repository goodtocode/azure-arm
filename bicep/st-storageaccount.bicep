@description('Name of the Storage Account. (st)')
@minLength(3)
@maxLength(24)
param name string

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('Sku of the Storage Account.')
@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GRS'
  'Standard_GZRS'
  'Standard_LRS'
  'Standard_RAGRS'
  'Standard_RAGZRS'
  'Standard_ZRS'
])
param sku string = 'Standard_LRS'

@description('Kind of the Storage Account.')
@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind string = 'StorageV2'

@description('Tags to add to the resources')
param tags object = {}

@description('Allow public access')
param allowBlobPublicAccess bool = false

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: allowBlobPublicAccess
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
        queue: {
          enabled: true
          keyType: 'Service'
        }
        table: {
          enabled: true
          keyType: 'Service'
        }
      }
    }
  }
}

output storageAccountId string = storageAccount.id
