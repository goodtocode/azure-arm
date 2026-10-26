targetScope = 'resourceGroup'

@description('Name of the WAF policy. 1-128 characters, letters and numbers only, starting with a letter.')
@minLength(1)
@maxLength(128)
param name string

@description('Tags to apply to the WAF policy.')
param tags object = {}

@description('SKU of the Front Door profile the policy attaches to. Bot protection requires Premium_AzureFrontDoor.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param sku string = 'Premium_AzureFrontDoor'

@description('Policy mode. Prevention blocks matching requests; Detection only logs them.')
@allowed([
  'Prevention'
  'Detection'
])
param mode string = 'Prevention'

@description('Version of the Microsoft_DefaultRuleSet managed rule set (OWASP-based).')
@minLength(1)
@maxLength(10)
param defaultRuleSetVersion string = '2.1'

@description('Version of the Microsoft_BotManagerRuleSet managed rule set. Applied only on Premium.')
@minLength(1)
@maxLength(10)
param botManagerRuleSetVersion string = '1.1'

@description('Maximum requests per client IP per minute before blocking. 0 disables the rate limit rule.')
@minValue(0)
@maxValue(100000)
param rateLimitThreshold int = 0

var defaultRuleSet = {
  ruleSetType: 'Microsoft_DefaultRuleSet'
  ruleSetVersion: defaultRuleSetVersion
  ruleSetAction: 'Block'
}

var botManagerRuleSet = {
  ruleSetType: 'Microsoft_BotManagerRuleSet'
  ruleSetVersion: botManagerRuleSetVersion
}

var rateLimitRule = {
  name: 'RateLimitPerClientIp'
  priority: 100
  enabledState: 'Enabled'
  ruleType: 'RateLimitRule'
  rateLimitDurationInMinutes: 1
  rateLimitThreshold: rateLimitThreshold
  action: 'Block'
  matchConditions: [
    {
      matchVariable: 'RequestUri'
      operator: 'Contains'
      negateCondition: false
      matchValue: [
        '/'
      ]
    }
  ]
}

resource waf 'Microsoft.Network/frontdoorWebApplicationFirewallPolicies@2024-02-01' = {
  name: name
  location: 'global'
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    policySettings: {
      enabledState: 'Enabled'
      mode: mode
      requestBodyCheck: 'Enabled'
    }
    managedRules: {
      managedRuleSets: sku == 'Premium_AzureFrontDoor' ? [
        defaultRuleSet
        botManagerRuleSet
      ] : [
        defaultRuleSet
      ]
    }
    customRules: {
      rules: rateLimitThreshold > 0 ? [
        rateLimitRule
      ] : []
    }
  }
}

@description('Resource ID of the WAF policy.')
output id string = waf.id
