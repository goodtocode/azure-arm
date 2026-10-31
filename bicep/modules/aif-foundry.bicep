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
param projectDescription string = 'Azure AI Foundry project.'

type FoundryModelName =
  | 'claude-opus-5-5'
  | 'claude-sonnet-5-5'
  | 'gpt-chat-latest'
  | 'gpt-6.1-sol'
  | 'gpt-6.1-terra'
  | 'gpt-6-astra'
  | 'gpt-6-luna'
  | 'gpt-6-sol'
  | 'gpt-5.6-sol'
  | 'gpt-5.6-terra'
  | 'gpt-5.6-luna'
  | 'gpt-5.5'
  | 'gpt-5.4'
  | 'gpt-5.4-pro'
  | 'gpt-5.4-mini'
  | 'gpt-5.4-nano'
  | 'gpt-5.3-codex'
  | 'gpt-4.1'
  | 'gpt-4.1-mini'
  | 'gpt-4.1-nano'
  | 'text-embedding-3-small'
  | 'text-embedding-3-large'
  | 'Cohere-embed-v3-english'
  | 'Cohere-embed-v3-multilingual'
  | 'Phi-4'
  | 'Phi-4-mini-instruct'
  | 'Phi-4-multimodal-instruct'
  | 'Phi-4-reasoning'
  | 'Phi-4-mini-reasoning'
  | 'MAI-Thinking-1'
  | 'MAI-Image-2.6'
  | 'MAI-Image-2.6-Flash'
  | 'MAI-Image-2.5'
  | 'MAI-Image-2.5-Flash'
  | 'MAI-Image-2.5-Pro'
  | 'MAI-Image-2e'
  | 'mai-code-1.1-flash'

type FoundryModelProviderData = {
  organizationName: string
  countryCode: string
  industry: 'technology' | 'finance' | 'healthcare' | 'education' | 'retail' | 'manufacturing' | 'government' | 'media' | 'other'
}

type FoundryDeploymentConfig = {
  deploymentName: string
  modelName: FoundryModelName
  modelFormat: 'OpenAI' | 'Microsoft' | 'Anthropic' | 'Cohere'
  modelVersion: string?
  modelProviderData: FoundryModelProviderData?
  raiPolicyName: string?
  skuName: 'Standard' | 'GlobalStandard'
  @description('Optional fixed deployment capacity that overrides the tokensPerMinute conversion, for models capped at a small capacity such as Cohere.')
  @minValue(1)
  capacity: int?
  @minValue(1000)
  tokensPerMinute: int
}

@description('Required list of current Foundry model deployments. modelVersion is optional; if omitted, Azure assigns the current default model version. Anthropic deployments require modelFormat Anthropic, modelProviderData attestation values, and typically raiPolicyName Microsoft.DefaultV2.')
@minLength(1)
param modelDeployments FoundryDeploymentConfig[]

@description('Approximate tokens-per-minute provided by one deployment capacity unit. Used to convert tokensPerMinute into deployment SKU capacity. Default is 1000 TPM per unit.')
@minValue(1)
param tokensPerMinutePerCapacityUnit int = 1000

@description('Enable diagnostics settings for the Azure AI Foundry hub resource.')
param enableDiagnostics bool = false

@description('Diagnostics settings configuration (if enabled).')
param diagnosticsSettings object = {}

@description('Default network action for the Azure AI Foundry hub. Use Deny for a private spoke deployment.')
@allowed([
  'Allow'
  'Deny'
])
param networkDefaultAction string = 'Allow'

@description('Controls whether the Azure AI Foundry hub accepts public network traffic.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Controls whether local key-based authentication is allowed. Use true for spoke deployments that require identity-based access.')
param disableLocalAuth bool = false

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
      defaultAction: networkDefaultAction
    }
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
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

@batchSize(1)
resource modelDeploymentsResource 'Microsoft.CognitiveServices/accounts/deployments@2026-05-01' = [for model in modelDeployments: {
  parent: foundryHub
  name: model.deploymentName
  dependsOn: [
    foundryProject
  ]
  sku: {
    name: model.skuName
    capacity: model.?capacity ?? int((model.tokensPerMinute + tokensPerMinutePerCapacityUnit - 1) / tokensPerMinutePerCapacityUnit)
  }
  properties: union({
    model: union({
      format: model.modelFormat
      name: model.modelName
    }, empty(model.?modelVersion) ? {} : {
      version: model.?modelVersion
    })
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: model.?raiPolicyName ?? 'Microsoft.Default'
  }, empty(model.?modelProviderData) ? {} : {
    // The service supports this required Anthropic attestation before the bundled Bicep type exposes it.
    #disable-next-line BCP037
    modelProviderData: model.?modelProviderData
  })
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
