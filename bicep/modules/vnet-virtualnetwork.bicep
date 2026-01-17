param name string
param addressPrefix string
param location string
param tags object = {}

resource vnetResource 'Microsoft.Network/virtualNetworks@2023-02-01' = {
	name: name
	location: location
	tags: empty(tags) ? null : tags
	properties: {
		addressSpace: {
			addressPrefixes: [ addressPrefix ]
		}
		enableDdosProtection: false
		enableVmProtection: false
	}
}

output id string = vnetResource.id
