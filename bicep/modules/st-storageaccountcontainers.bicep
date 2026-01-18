
@description('The name of the Storage Account. Must be globally unique, 3-24 characters, using only lowercase letters and numbers.')
@minLength(3)
@maxLength(24)
param name string

@description('The SKU (pricing tier) of the Storage Account. Allowed values: Premium_LRS, Premium_ZRS, Standard_GRS, Standard_GZRS, Standard_LRS, Standard_RAGRS, Standard_RAGZRS, Standard_ZRS. Default is Standard_LRS.')
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

@description('The kind of the Storage Account. Allowed values: BlobStorage, BlockBlobStorage, FileStorage, Storage, StorageV2. Default is StorageV2.')
@allowed([
  'BlobStorage'
  'BlockBlobStorage'
  'FileStorage'
  'Storage'
  'StorageV2'
])
param kind string = 'StorageV2'

@description('Allow public access to blobs in the Storage Account. Default is false.')
param allowBlobPublicAccess bool = false

@description('Array of container JSON objects. Example: {resources: [{name: \'mycontainer\', publicAccess: \'None\'}]}')
param containerResources object = {
  resources: [
    {
      name: 'mycontainer'
      publicAccess: 'None'
    }
  ]
}

resource name_resource 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: resourceGroup().location
  tags: {
    displayName: name
  }
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: allowBlobPublicAccess
  }
}

resource name_default 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: name_resource
  name: 'default'
  sku: {
    name: sku
  }
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_fileServices_name_default 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: name_resource
  name: 'default'
  sku: {
    name: sku
  }
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_queueServices_name_default 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  parent: name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource Microsoft_Storage_storageAccounts_tableServices_name_default 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = {
  parent: name_resource
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}
