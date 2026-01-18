
@description('Name of the Azure Front Door instance')
param name string

@description('Location for the Azure Front Door (must be global)')
param location string = 'global'

@description('Tags to apply to the resource')
param tags object = {}

@description('SKU for Azure Front Door')
@allowed(['Standard_AzureFrontDoor', 'Premium_AzureFrontDoor'])
param sku string = 'Standard_AzureFrontDoor'

resource afd 'Microsoft.Cdn/profiles@2023-05-01' = {
	name: name
	location: location
	tags: tags
	sku: {
		name: sku
	}
}

output id string = afd.id
