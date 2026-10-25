@minLength(1)
@maxLength(80)
@description('The name of the public IP address. 1-80 characters.')
param name string

@description('The Azure region where the public IP address will be deployed.')
param location string = resourceGroup().location

@description('Tags to apply to the public IP address.')
param tags object = {}

resource pip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

@description('Resource ID of the public IP address.')
output id string = pip.id
