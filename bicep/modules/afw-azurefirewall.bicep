targetScope = 'resourceGroup'

@description('Name of the Azure Firewall. 1-49 characters.')
@minLength(1)
@maxLength(49)
param name string

@description('Location of the Azure Firewall.')
param location string = resourceGroup().location

@description('Tags to apply to the firewall and its policy.')
param tags object = {}

@description('Resource ID of the AzureFirewallSubnet subnet.')
param subnetId string

@description('Resource ID of the Standard static public IP used by the firewall.')
param publicIpId string

@description('Firewall tier. Premium adds TLS inspection and IDPS.')
@allowed([
  'Standard'
  'Premium'
])
param tier string = 'Standard'

@description('Threat intelligence mode of the firewall policy.')
@allowed([
  'Off'
  'Alert'
  'Deny'
])
param threatIntelMode string = 'Alert'

resource policy 'Microsoft.Network/firewallPolicies@2023-11-01' = {
  name: '${name}-policy'
  location: location
  tags: tags
  properties: {
    sku: {
      tier: tier
    }
    threatIntelMode: threatIntelMode
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: tier
    }
    firewallPolicy: {
      id: policy.id
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}

@description('Resource ID of the Azure Firewall.')
output id string = firewall.id

@description('Resource ID of the firewall policy. Add rule collection groups to it.')
output policyId string = policy.id

@description('Private IP of the firewall, used as the next hop for spoke route tables.')
output privateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
