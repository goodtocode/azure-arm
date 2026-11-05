targetScope = 'resourceGroup'

@description('Name of the WAF policy. 1-128 characters.')
@minLength(1)
@maxLength(128)
param name string

@description('Location of the WAF policy.')
param location string = resourceGroup().location

@description('Tags to apply to the WAF policy.')
param tags object = {}

@description('Policy mode. Prevention blocks matching requests; Detection only logs them.')
@allowed([
  'Prevention'
  'Detection'
])
param mode string = 'Prevention'

@description('Version of the OWASP managed rule set.')
@allowed([
  '3.2'
  '3.1'
])
param owaspRuleSetVersion string = '3.2'

@description('Version of the Microsoft_BotManagerRuleSet managed rule set.')
@allowed([
  '1.0'
  '1.1'
])
param botManagerRuleSetVersion string = '1.0'

resource waf 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: mode
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: owaspRuleSetVersion
        }
        {
          ruleSetType: 'Microsoft_BotManagerRuleSet'
          ruleSetVersion: botManagerRuleSetVersion
        }
      ]
    }
  }
}

@description('Resource ID of the WAF policy.')
output id string = waf.id
