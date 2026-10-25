@description('Name of the existing virtual network to add the subnet to')
param vnetName string

@description('Name of the subnet to create')
param snetName string

@description('Address prefix for the subnet (e.g., 10.0.0.0/24)')
param cidr string

@description('Resource ID of the Network Security Group to associate with the subnet')
param nsgId string = ''

@description('Resource ID of the route table to associate with the subnet. Leave empty for system routes.')
param routeTableId string = ''

@description('Service the subnet is delegated to, for example Microsoft.Web/serverFarms for App Service regional VNet integration. Leave empty for no delegation.')
param delegation string = ''

@description('Service endpoints enabled on the subnet, for example Microsoft.Storage or Microsoft.Sql.')
param serviceEndpoints string[] = []

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
	name: '${vnetName}/${snetName}'
	properties: {
		addressPrefix: cidr
		networkSecurityGroup: empty(nsgId) ? null : {
			id: nsgId
		}
		routeTable: empty(routeTableId) ? null : {
			id: routeTableId
		}
		delegations: empty(delegation) ? [] : [
			{
				name: 'delegation'
				properties: {
					serviceName: delegation
				}
			}
		]
		serviceEndpoints: [for endpoint in serviceEndpoints: {
			service: endpoint
		}]
	}
}

@description('Resource ID of the subnet.')
output id string = subnet.id
