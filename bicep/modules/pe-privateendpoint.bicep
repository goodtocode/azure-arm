@description('Name of the private endpoint. 2-80 characters.')
@minLength(2)
@maxLength(80)
param name string

@description('Azure region of the private endpoint. It must match the region of the VNet.')
param location string = resourceGroup().location

@description('Tags to apply to the private endpoint.')
param tags object = {}

@description('Resource ID of the subnet that hosts the private endpoint network interface.')
param subnetId string

@description('Resource ID of the resource the private endpoint connects to.')
param targetResourceId string

@description('Sub-resource (group ID) to connect to, for example sites, sqlServer, blob, file, queue, table.')
@minLength(1)
param groupId string

@description('Resource ID of the Private DNS zone that receives the endpoint record, for example privatelink.azurewebsites.net.')
param privateDnsZoneId string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    subnet: {
      id: subnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-connection'
        properties: {
          privateLinkServiceId: targetResourceId
          groupIds: [groupId]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the private endpoint.')
output id string = privateEndpoint.id
