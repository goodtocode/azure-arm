targetScope = 'resourceGroup'

@description('Azure region for resource deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to resources. Must be an object.')
param tags object

@minLength(3)
@maxLength(63)
@description('Name of the Azure OpenAI instance. Must be globally unique, 3-63 characters, using only lowercase letters, numbers, and hyphens, starting and ending with a letter or number.')
param azoaiName string

@allowed([
  'S0'
])
@description('SKU for Azure OpenAI. Allowed value: S0. Defaults to S0.')
param azoaiSku string = 'S0'

type AoaiModelName =
  | 'gpt-5.6-sol'
  | 'gpt-5.6-terra'
  | 'gpt-5.6-luna'
  | 'gpt-5.5'
  | 'gpt-5.4'
  | 'gpt-5.4-mini'
  | 'gpt-5.4-nano'
  | 'gpt-5.4-pro'
  | 'gpt-5'
  | 'gpt-5-mini'
  | 'gpt-5-nano'
  | 'gpt-4.1'
  | 'gpt-4.1-mini'
  | 'gpt-4.1-nano'
  | 'gpt-4o'
  | 'gpt-4o-mini'
  | 'text-embedding-3-large'
  | 'text-embedding-3-small'

type AoaiDeploymentConfig = {
  deploymentName: string
  modelName: AoaiModelName
  modelFormat: 'OpenAI'
  modelVersion: string
  deploymentSkuName: 'Standard' | 'GlobalStandard'
  deploymentSkuCapacity: int
}

@description('Required list of model deployments. Each object creates one Azure OpenAI deployment.')
@minLength(1)
param modelDeployments AoaiDeploymentConfig[]

module azoaiModule '../modules/aoai-azureopenai.bicep' = {
  name: 'azoaiModule'
  params: {
    name: azoaiName
    sku: azoaiSku
    location: location
    tags: tags
    modelDeployments: modelDeployments
    }
  }

output azoaiResourceId string = azoaiModule.outputs.id
output endpoint string = azoaiModule.outputs.endpoint
output primaryAccessKey string = azoaiModule.outputs.primaryAccessKey
output secondaryAccessKey string = azoaiModule.outputs.secondaryAccessKey
output deployedModelName string = azoaiModule.outputs.deployedModelName
output deployedModelVersion string = azoaiModule.outputs.deployedModelVersion
output deployedModelDeploymentName string = azoaiModule.outputs.deployedModelDeploymentName
output deployedModelNames array = azoaiModule.outputs.deployedModelNames
output deployedModelVersions array = azoaiModule.outputs.deployedModelVersions
output deployedModelDeploymentNames array = azoaiModule.outputs.deployedModelDeploymentNames
