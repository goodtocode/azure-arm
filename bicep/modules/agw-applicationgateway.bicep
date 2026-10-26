targetScope = 'resourceGroup'

@description('Name of the Application Gateway. 2-80 characters.')
@minLength(2)
@maxLength(80)
param name string

@description('Location of the Application Gateway.')
param location string = resourceGroup().location

@description('Tags to apply to the Application Gateway.')
param tags object = {}

@description('Resource ID of the dedicated Application Gateway subnet.')
param subnetId string

@description('Resource ID of the Standard static public IP used for the frontend.')
param publicIpId string

@description('Resource ID of the WAF policy.')
param wafPolicyId string

@minValue(0)
@maxValue(125)
@description('Minimum autoscale instance count.')
param minCapacity int = 1

@minValue(1)
@maxValue(125)
@description('Maximum autoscale instance count.')
param maxCapacity int = 2

@description('Sites served by the gateway, one HTTP listener, backend pool and routing rule each.')
param backends backendType[]

type backendType = {
  @minLength(2)
  @maxLength(80)
  @description('Name shared by the listener, pool, settings, probe and rule.')
  name: string

  @minLength(1)
  @maxLength(253)
  @description('Host name the listener matches, e.g. app.example.com.')
  hostName: string

  @minLength(1)
  @maxLength(253)
  @description('Backend FQDN, e.g. the App Service default host name. Reached over HTTPS.')
  backendFqdn: string
}

var frontendIpName = 'publicFrontend'
var frontendPortName = 'http'

resource agw 'Microsoft.Network/applicationGateways@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    firewallPolicy: {
      id: wafPolicyId
    }
    gatewayIPConfigurations: [
      {
        name: 'gatewayIp'
        properties: {
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: frontendIpName
        properties: {
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: frontendPortName
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [for b in backends: {
      name: b.name
      properties: {
        backendAddresses: [
          {
            fqdn: b.backendFqdn
          }
        ]
      }
    }]
    probes: [for b in backends: {
      name: b.name
      properties: {
        protocol: 'Https'
        path: '/'
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        pickHostNameFromBackendHttpSettings: true
        match: {
          statusCodes: [
            '200-399'
          ]
        }
      }
    }]
    backendHttpSettingsCollection: [for b in backends: {
      name: b.name
      properties: {
        port: 443
        protocol: 'Https'
        requestTimeout: 30
        pickHostNameFromBackendAddress: true
        probe: {
          id: resourceId('Microsoft.Network/applicationGateways/probes', name, b.name)
        }
      }
    }]
    httpListeners: [for b in backends: {
      name: b.name
      properties: {
        frontendIPConfiguration: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, frontendIpName)
        }
        frontendPort: {
          id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, frontendPortName)
        }
        protocol: 'Http'
        hostName: b.hostName
      }
    }]
    requestRoutingRules: [for (b, i) in backends: {
      name: b.name
      properties: {
        ruleType: 'Basic'
        priority: 100 + i
        httpListener: {
          id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, b.name)
        }
        backendAddressPool: {
          id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, b.name)
        }
        backendHttpSettings: {
          id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, b.name)
        }
      }
    }]
  }
}

@description('Resource ID of the Application Gateway.')
output id string = agw.id
