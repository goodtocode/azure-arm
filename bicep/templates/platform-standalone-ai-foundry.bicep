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
param projectDescription string = 'Cannery spoke AI project.'

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

@description('Required list of model deployments. Each object creates one Azure AI Foundry model deployment.')
@minLength(1)
param modelDeployments FoundryDeploymentConfig[]

module foundryModule '../modules/aif-foundry.bicep' = {
  name: 'foundryModule'
  params: {
    name: foundryName
    location: location
    tags: tags
    projectName: projectName
    projectDescription: projectDescription
    modelDeployments: modelDeployments
  }
}

@description('Resource ID of the Azure AI Foundry hub account.')
output foundryResourceId string = foundryModule.outputs.resourceId

@description('Endpoint URI for the Azure AI Foundry hub account.')
output endpoint string = foundryModule.outputs.endpoint

@description('Name of the first deployed model deployment.')
output deploymentName string = foundryModule.outputs.deploymentName

@description('Names of all model deployments created in this deployment.')
output deploymentNames array = foundryModule.outputs.deploymentNames

@description('Name of the Azure AI Foundry project created in this deployment.')
output projectName string = foundryModule.outputs.projectName

@description('Resource ID of the Azure AI Foundry project created in this deployment.')
output projectResourceId string = foundryModule.outputs.projectResourceId
