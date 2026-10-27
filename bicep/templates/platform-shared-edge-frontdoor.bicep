targetScope = 'resourceGroup'

// Common
param tags object

@minLength(3)
@maxLength(63)
@description('Specifies the name of the Azure Front Door profile. 3-63 characters, lowercase letters, numbers, and -')
param afdName string

@description('Specifies the SKU for Azure Front Door. Premium adds bot protection and Private Link.')
@allowed([
  'Standard_AzureFrontDoor'
  'Premium_AzureFrontDoor'
])
param afdSku string = 'Premium_AzureFrontDoor'

@description('Specifies the WAF mode. Prevention blocks matching requests; Detection only logs them.')
@allowed([
  'Prevention'
  'Detection'
])
param wafMode string = 'Prevention'

@minValue(0)
@maxValue(100000)
@description('Specifies the maximum requests per client IP per minute before blocking. 0 disables the rate limit rule.')
param wafRateLimitThreshold int = 0

@description('Specifies the products served through Front Door, one endpoint per entry.')
param origins originType[] = []

type originType = {
  @minLength(1)
  @maxLength(46)
  @description('Endpoint, origin group and route name. Letters, numbers and -')
  name: string

  @minLength(1)
  @maxLength(253)
  @description('Origin host name, e.g. the App Service default host name.')
  originHostName: string

  @maxLength(253)
  @description('Custom domain, e.g. app.example.com. Omit to use the default Front Door host name.')
  customDomainHostName: string?

  @maxLength(255)
  @description('Health probe path. Defaults to /.')
  healthProbePath: string?
}

module afd '../modules/afd-azurefrontdoor.bicep' = {
  name: 'afdName'
  params: {
    name: afdName
    location: 'global'
    tags: tags
    sku: afdSku
  }
}

module waf '../modules/afdwaf-frontdoorwafpolicy.bicep' = {
  name: 'wafName'
  params: {
    name: '${replace(afdName, '-', '')}waf'
    tags: tags
    sku: afdSku
    mode: wafMode
    rateLimitThreshold: wafRateLimitThreshold
  }
}

module origin '../modules/afdorigin-frontdoororigin.bicep' = [for o in origins: {
  name: 'afdOrigin-${o.name}'
  dependsOn: [
    afd
  ]
  params: {
    profileName: afdName
    name: o.name
    originHostName: o.originHostName
    customDomainHostName: o.?customDomainHostName ?? ''
    healthProbePath: o.?healthProbePath ?? '/'
  }
}]

module security '../modules/afdsec-frontdoorsecuritypolicy.bicep' = if (!empty(origins)) {
  name: 'afdSecurityName'
  params: {
    profileName: afdName
    name: '${afdName}-waf'
    wafPolicyId: waf.outputs.id
    domainIds: [for (o, i) in origins: origin[i].outputs.endpointId]
    customDomainIds: [for (o, i) in origins: origin[i].outputs.customDomainId]
  }
}

@description('Default host names of the Front Door endpoints, in origin order. Point DNS CNAME records for custom domains at these.')
output endpointHostNames array = [for (o, i) in origins: origin[i].outputs.endpointHostName]

@description('DNS TXT validation tokens for custom domains, in origin order. Empty when no custom domain is set.')
output customDomainValidationTokens array = [for (o, i) in origins: origin[i].outputs.customDomainValidationToken]

@description('Resource ID of the Front Door profile.')
output resourceId string = afd.outputs.id
