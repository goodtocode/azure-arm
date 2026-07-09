@description('Name of the Azure AI Foundry hub (Cognitive Services account). Must be globally unique, 3-63 characters, lowercase letters, numbers, and hyphens.')
@minLength(3)
@maxLength(63)
param name string

@description('Location for the Azure AI Foundry resources.')
param location string

@description('Tags to apply to Azure AI Foundry resources.')
param tags object = {}

@description('Azure AI Foundry project name. This is used for logical project association and output contracts.')
@minLength(2)
@maxLength(64)
param projectName string

@description('Optional human-readable description for the Azure AI Foundry project resource.')
@maxLength(256)
param projectDescription string = 'Standalone Azure AI Foundry project for Crucible.'

@description('Name of the model to deploy.')
@allowed([
  'claude-opus'
  'claude-sonnet'
  'gpt-5.4'
  'gpt-4.1'
  'gpt-4.1-mini'
  'phi-4'
  'mai-code'
])
param modelName string = 'gpt-4.1-mini'

@description('Model format required by Azure AI model deployment.')
@allowed([
  'OpenAI'
])
param modelFormat string = 'OpenAI'

@description('Model version. Keep configurable because model availability varies by region and subscription.')
param modelVersion string = '2025-04-14'

@description('Deployment name exposed to provider configuration.')
@minLength(1)
@maxLength(64)
param deploymentName string = 'default'

@description('SKU for model deployment.')
@allowed([
  'Standard'
  'GlobalStandard'
])
param skuName string = 'Standard'

@description('Deployment capacity. For Standard SKU this is the unit count.')
@minValue(1)
param skuCapacity int = 1

@description('Enable diagnostics settings for the Azure AI Foundry hub resource.')
param enableDiagnostics bool = false

@description('Diagnostics settings configuration (if enabled).')
param diagnosticsSettings object = {}

resource foundryHub 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: name
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: foundryHub
  name: projectName
  location: location
  properties: {
    displayName: projectName
    description: projectDescription
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: foundryHub
  name: deploymentName
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    model: {
      format: modelFormat
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}

resource foundryHubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${foundryHub.name}-diagnostics'
  scope: foundryHub
  properties: diagnosticsSettings
}

output endpoint string = foundryHub.properties.endpoint
output deploymentName string = modelDeployment.name
output projectName string = projectName
output resourceId string = foundryHub.id
output projectResourceId string = foundryProject.id
