
@description('The name of the Service Bus namespace. Must be 6-50 characters, using only alphanumeric characters and hyphens.')
@minLength(6)
@maxLength(50)
param name string

@description('The SKU (pricing tier) for the Service Bus namespace. Allowed values: Basic, Standard, Premium. Default is Basic.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Basic'


@description('Specifies the Azure location where the Service Bus namespace should be created.')
param location string = toLower(replace(resourceGroup().location, ' ', ''))

var nameAlphaNumeric_var = replace(replace(name, '-', ''), '.', '')

resource nameAlphaNumeric 'Microsoft.ServiceBus/namespaces@2021-11-01' = {
  name: nameAlphaNumeric_var
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    zoneRedundant: false
  }
}

resource nameAlphaNumeric_RootManageSharedAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2021-11-01' = {
  parent: nameAlphaNumeric
  name: 'RootManageSharedAccessKey'
  location: location
  properties: {
    rights: [
      'Listen'
      'Manage'
      'Send'
    ]
  }
}

resource nameAlphaNumeric_default 'Microsoft.ServiceBus/namespaces/networkRuleSets@2021-11-01' = if (sku == 'Premium') {
  parent: nameAlphaNumeric
  name: 'default'
  location: location
  properties: {
    defaultAction: 'Deny'
    virtualNetworkRules: []
    ipRules: []
  }
}
