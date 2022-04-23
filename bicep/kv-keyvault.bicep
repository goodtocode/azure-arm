param deploy bool = false

@description('Domain name. I.e. ntievents, certtestcenter, PRODUCT, ')
param name string

@description('Sku of the key vault.')
param sku string = 'premium'

resource name_resource 'Microsoft.KeyVault/vaults@2016-10-01' = if (deploy) {
  name: name
  location: resourceGroup().location
  tags: {
    displayName: 'KeyVault'
  }
  properties: {
    createMode: 'default'
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    tenantId: subscription().tenantId
    sku: {
      name: sku
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
    }
    accessPolicies: []
  }
}