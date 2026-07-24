targetScope = 'resourceGroup'

@description('Azure region for deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to all deployed resources.')
param tags object = {}

@minLength(3)
@maxLength(63)
@description('Name of the Azure AI Foundry hub (Cognitive Services account). Must be globally unique and lowercase.')
param foundryName string

@minLength(2)
@maxLength(64)
@description('Azure AI Foundry project name for logical project grouping.')
param projectName string

type FoundryModelName =
  | 'claude-opus'
  | 'claude-sonnet'
  | 'gpt-5.4'
  | 'gpt-4.1'
  | 'gpt-4.1-mini'
  | 'phi-4'
  | 'mai-image-2.5'
  | 'mai-image-2.5-flash'
  | 'mai-image-2.5-pro'
  | 'mai-code'

type FoundryDeploymentConfig = {
  deploymentName: string
  modelName: FoundryModelName
  modelFormat: 'OpenAI'
  modelVersion: string
  skuName: 'Standard' | 'GlobalStandard'
  skuCapacity: int
}

@description('Required list of model deployments. Each object deploys one model. Allowed modelName values: claude-opus, claude-sonnet, gpt-5.4, gpt-4.1, gpt-4.1-mini, phi-4, mai-code, mai-image-2.5, mai-image-2.5-flash, mai-image-2.5-pro.')
@minLength(1)
param modelDeployments FoundryDeploymentConfig[]

@description('Enable diagnostics for Foundry hub resource.')
param enableDiagnostics bool = false

@description('Diagnostics settings payload for Foundry hub resource when diagnostics are enabled.')
param diagnosticsSettings object = {}

module foundryModule '../modules/aif-foundry.bicep' = {
  name: 'foundryModule'
  params: {
    name: foundryName
    location: location
    tags: tags
    projectName: projectName
    modelDeployments: modelDeployments
    enableDiagnostics: enableDiagnostics
    diagnosticsSettings: diagnosticsSettings
  }
}

output endpoint string = foundryModule.outputs.endpoint
output deploymentName string = foundryModule.outputs.deploymentName
output deploymentNames array = foundryModule.outputs.deploymentNames
output projectName string = foundryModule.outputs.projectName
output resourceId string = foundryModule.outputs.resourceId
output projectResourceId string = foundryModule.outputs.projectResourceId
