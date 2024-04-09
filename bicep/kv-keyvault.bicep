@description('Specifies the name of the key vault.')
param name string

@description('Specifies the Azure location where the key vault should be created.')
param location string = resourceGroup().location

@description('Sku of the key vault.')
@allowed([
  'standard'
  'premium'
])
param sku string = 'standard'

@description('Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault. Get it by using Get-AzSubscription cmdlet.')
param tenantId string = subscription().tenantId

resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: tenantId
    publicNetworkAccess:'Enabled'
    accessPolicies: []
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
  }
} 
