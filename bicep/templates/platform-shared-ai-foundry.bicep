targetScope = 'resourceGroup'

@description('Azure region for resource deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to resources. Must be an object.')
param tags object

@minLength(3)
@maxLength(63)
@description('Name of the Azure AI Foundry hub account. Must be globally unique, 3-63 characters, lowercase letters, numbers, and hyphens.')
param foundryName string

@minLength(2)
@maxLength(64)
@description('Name of the Azure AI Foundry project associated with this hub.')
param projectName string

@maxLength(256)
@description('Optional human-readable description for the Azure AI Foundry project.')
param projectDescription string = 'Spoke AI project.'

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
  @minValue(1000)
  tokensPerMinute: int
}

@description('Required list of model deployments. Each object creates one Azure AI Foundry model deployment.')
@minLength(1)
param modelDeployments FoundryDeploymentConfig[]

@description('Approximate tokens-per-minute provided by one deployment capacity unit. Used to convert tokensPerMinute into deployment SKU capacity. Default is 1000 TPM per unit.')
@minValue(1)
param tokensPerMinutePerCapacityUnit int = 1000

module aifModule '../modules/aif-foundry.bicep' = {
  name: 'aifModule'
  params: {
    name: foundryName
    location: location
    tags: tags
    projectName: projectName
    projectDescription: projectDescription
    modelDeployments: modelDeployments
    tokensPerMinutePerCapacityUnit: tokensPerMinutePerCapacityUnit
  }
}

@description('Resource ID of the Azure AI Foundry hub account.')
output foundryResourceId string = aifModule.outputs.resourceId

@description('Endpoint URI for the Azure AI Foundry hub account.')
output endpoint string = aifModule.outputs.endpoint

@description('Name of the first deployed model deployment.')
output deploymentName string = aifModule.outputs.deploymentName

@description('Names of all model deployments created in this deployment.')
output deploymentNames array = aifModule.outputs.deploymentNames

@description('Name of the Azure AI Foundry project created in this deployment.')
output projectName string = aifModule.outputs.projectName

@description('Resource ID of the Azure AI Foundry project created in this deployment.')
output projectResourceId string = aifModule.outputs.projectResourceId
