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

@description('Model name to deploy for Foundry inference.')
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

@minLength(1)
@maxLength(64)
@description('Deployment name exposed to Crucible provider configuration.')
param deploymentName string = 'default'

@description('SKU for model deployment.')
@allowed([
  'Standard'
  'GlobalStandard'
])
param skuName string = 'Standard'

@description('Model format for deployment.')
@allowed([
  'OpenAI'
])
param modelFormat string = 'OpenAI'

@description('Model version for deployment. Keep configurable for regional model availability.')
param modelVersion string = '2025-04-14'

@description('Capacity units for deployment SKU.')
@minValue(1)
param skuCapacity int = 1

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
    modelName: modelName
    deploymentName: deploymentName
    skuName: skuName
    modelFormat: modelFormat
    modelVersion: modelVersion
    skuCapacity: skuCapacity
    enableDiagnostics: enableDiagnostics
    diagnosticsSettings: diagnosticsSettings
  }
}

output endpoint string = foundryModule.outputs.endpoint
output deploymentName string = foundryModule.outputs.deploymentName
output projectName string = foundryModule.outputs.projectName
output resourceId string = foundryModule.outputs.resourceId
output projectResourceId string = foundryModule.outputs.projectResourceId
