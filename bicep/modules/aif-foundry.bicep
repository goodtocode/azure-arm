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
param projectDescription string = 'Standalone Azure AI Foundry project.'

type FoundryModelName =
  | 'claude-opus'
  | 'claude-sonnet'
  | 'gpt-5.4'
  | 'gpt-5.3-chat'
  | 'gpt-5.3-codex'
  | 'gpt-4.1'
  | 'gpt-4.1-mini'
  | 'phi-4'
  | 'Phi-4'
  | 'MAI-Image-2'
  | 'MAI-Image-2.5'
  | 'MAI-Image-2.5-Flash'
  | 'MAI-Image-2.5-Pro'
  | 'MAI-Image-2e'

type FoundryDeploymentConfig = {
  deploymentName: string
  modelName: FoundryModelName
  modelFormat: 'OpenAI' | 'Microsoft'
  modelVersion: string?
  skuName: 'Standard' | 'GlobalStandard'
  @minValue(1000)
  tokensPerMinute: int
}

@description('Required list of model deployments. Each object deploys one model. Allowed modelName values: claude-opus, claude-sonnet, gpt-5.4, gpt-4.1, gpt-4.1-mini, phi-4, MAI-Image-2, MAI-Image-2.5, MAI-Image-2.5-Flash, MAI-Image-2.5-Pro, MAI-Image-2e. modelVersion is optional; if omitted, Azure assigns the current default model version.')
@minLength(1)
param modelDeployments FoundryDeploymentConfig[]

@description('Approximate tokens-per-minute provided by one deployment capacity unit. Used to convert tokensPerMinute into deployment SKU capacity. Default is 1000 TPM per unit.')
@minValue(1)
param tokensPerMinutePerCapacityUnit int = 1000

@description('Enable diagnostics settings for the Azure AI Foundry hub resource.')
param enableDiagnostics bool = false

@description('Diagnostics settings configuration (if enabled).')
param diagnosticsSettings object = {}

resource foundryHub 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: name
    networkAcls: {
      defaultAction: 'Allow'
    }
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundryHub
  name: projectName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: projectName
    description: projectDescription
  }
}

@batchSize(1) // Remove if doesnt help
resource modelDeploymentsResource 'Microsoft.CognitiveServices/accounts/deployments@2026-05-01' = [for model in modelDeployments: {
  parent: foundryHub
  name: model.deploymentName
  dependsOn: [
    foundryProject
  ]
  sku: {
    name: model.skuName
    capacity: int((model.tokensPerMinute + tokensPerMinutePerCapacityUnit - 1) / tokensPerMinutePerCapacityUnit)
  }
  properties: {
    model: union({
      format: model.modelFormat
      name: model.modelName
    }, empty(model.?modelVersion) ? {} : {
      version: model.?modelVersion
    })
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

resource foundryHubDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics) {
  name: '${foundryHub.name}-diagnostics'
  scope: foundryHub
  properties: diagnosticsSettings
}

output endpoint string = foundryHub.properties.endpoint
output deploymentName string = modelDeploymentsResource[0].name
output deploymentNames array = [for i in range(0, length(modelDeployments)): modelDeploymentsResource[i].name]
output projectName string = projectName
output resourceId string = foundryHub.id
output projectResourceId string = foundryProject.id
