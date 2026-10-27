targetScope = 'resourceGroup'

@description('Name of the existing Front Door profile.')
@minLength(3)
@maxLength(63)
param profileName string

@description('Name of the endpoint, origin group, origin and route. 1-46 characters, letters, numbers and -. The endpoint host name is derived from it.')
@minLength(1)
@maxLength(46)
param name string

@description('Host name of the origin, e.g. the App Service default host name.')
@minLength(1)
@maxLength(253)
param originHostName string

@description('Optional custom domain served by this endpoint, e.g. app.example.com. Empty for none. Uses a Front Door managed certificate.')
@maxLength(253)
param customDomainHostName string = ''

@description('Path used by the origin health probe.')
@minLength(1)
@maxLength(255)
param healthProbePath string = '/'

resource profile 'Microsoft.Cdn/profiles@2023-05-01' existing = {
  name: profileName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2023-05-01' = {
  parent: profile
  name: name
  location: 'global'
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2023-05-01' = {
  parent: profile
  name: name
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: healthProbePath
      probeRequestType: 'HEAD'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2023-05-01' = {
  parent: originGroup
  name: name
  properties: {
    hostName: originHostName
    originHostHeader: originHostName
    httpPort: 80
    httpsPort: 443
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2023-05-01' = if (!empty(customDomainHostName)) {
  parent: profile
  name: replace(customDomainHostName, '.', '-')
  properties: {
    hostName: customDomainHostName
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2023-05-01' = {
  parent: endpoint
  name: name
  dependsOn: [
    origin
  ]
  properties: {
    originGroup: {
      id: originGroup.id
    }
    customDomains: !empty(customDomainHostName) ? [
      {
        id: customDomain.id
      }
    ] : []
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

@description('Resource ID of the endpoint.')
output endpointId string = endpoint.id

@description('Default host name of the endpoint.')
output endpointHostName string = endpoint.properties.hostName

@description('Resource ID of the custom domain. Empty when none is configured.')
output customDomainId string = !empty(customDomainHostName) ? customDomain.id : ''

@description('DNS TXT validation token for the custom domain. Empty when none is configured.')
output customDomainValidationToken string = !empty(customDomainHostName) ? customDomain!.properties.validationProperties.validationToken : ''
