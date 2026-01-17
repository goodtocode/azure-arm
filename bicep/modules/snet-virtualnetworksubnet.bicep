

@description('Name of the existing virtual network to add the subnet to')
param vnetName string

@description('Name of the subnet to create')
param snetName string

@description('Address prefix for the subnet (e.g., 10.0.0.0/24)')
param cidr string


resource subnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
	name: '${vnetName}/${snetName}'
	properties: {
		addressPrefix: cidr
	}
}

output id string = subnet.id
