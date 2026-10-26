targetScope = 'resourceGroup'

@description('Name of the existing Front Door profile.')
@minLength(3)
@maxLength(63)
param profileName string

@description('Name of the security policy.')
@minLength(1)
@maxLength(260)
param name string

@description('Resource ID of the WAF policy to associate.')
param wafPolicyId string

@description('Resource IDs of the endpoints the WAF policy protects.')
param domainIds array

@description('Resource IDs of the custom domains the WAF policy protects. Empty entries are ignored.')
param customDomainIds array = []

var allDomainIds = filter(concat(domainIds, customDomainIds), id => !empty(id))

resource profile 'Microsoft.Cdn/profiles@2023-05-01' existing = {
  name: profileName
}

resource securityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2023-05-01' = {
  parent: profile
  name: name
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: wafPolicyId
      }
      associations: [
        {
          domains: [for id in allDomainIds: {
            id: id
          }]
          patternsToMatch: [
            '/*'
          ]
        }
      ]
    }
  }
}

@description('Resource ID of the security policy.')
output id string = securityPolicy.id
