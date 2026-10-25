@minLength(1)
@maxLength(80)
@description('The name of the network interface. 1-80 characters.')
param name string

@description('The Azure region where the network interface will be deployed.')
param location string = resourceGroup().location

@description('Tags to apply to the network interface.')
param tags object = {}

@minLength(1)
@description('Resource ID of the subnet the network interface attaches to.')
param subnetId string

@description('Resource ID of a public IP address to attach. Leave empty for a private-only interface.')
param publicIpId string = ''

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: empty(publicIpId) ? null : {
            id: publicIpId
          }
        }
      }
    ]
  }
}

@description('Resource ID of the network interface.')
output id string = nic.id
