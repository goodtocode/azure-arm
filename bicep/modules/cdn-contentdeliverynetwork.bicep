
@description('The name of the Storage Account for CDN. Must be 3-24 characters, using only lowercase letters and numbers.')
@minLength(3)
@maxLength(24)
param name string

@description('The SKU (pricing tier) for the Storage Account. Allowed values: Standard_LRS, Standard_GRS, Standard_RAGRS, Standard_ZRS, Premium_LRS, Premium_ZRS. Default is Standard_LRS.')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
])
param sku string = 'Standard_LRS'

var storageAccountName_var = name

resource storageAccountName 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName_var
  location: resourceGroup().location
  tags: {
    displayName: storageAccountName_var
  }
  sku: {
    name: sku
  }
  kind: 'Storage'
}
