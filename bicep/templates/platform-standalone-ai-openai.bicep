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

@description('When true, deploys a model deployment into the Azure OpenAI account.')
param deployModel bool = true

@description('Deployment name clients use at runtime for Azure OpenAI calls.')
@minLength(1)
@maxLength(64)
param modelDeploymentName string = 'default'

@description('Model name to deploy when deployModel is true.')
@allowed([
  'gpt-4.1'
  'gpt-4.1-mini'
  'gpt-4o'
  'gpt-4o-mini'
  'text-embedding-3-large'
  'text-embedding-3-small'
])
param modelName string = 'gpt-4.1-mini'

@description('Model format required by Azure OpenAI deployment.')
@allowed([
  'OpenAI'
])
param modelFormat string = 'OpenAI'

@description('Model version. Keep configurable because availability varies by region and subscription.')
param modelVersion string = '2025-04-14'

@description('Model deployment SKU name.')
@allowed([
  'Standard'
  'GlobalStandard'
])
param modelDeploymentSkuName string = 'Standard'

@description('Model deployment SKU capacity.')
@minValue(1)
param modelDeploymentSkuCapacity int = 1

module azoaiModule '../modules/azoai-azureopenai.bicep' = {
  name: 'azoaiModule'
  params: {
    name: azoaiName
    sku: azoaiSku
    location: location
    tags: tags
    deployModel: deployModel
    deploymentName: modelDeploymentName
    modelName: modelName
    modelFormat: modelFormat
    modelVersion: modelVersion
    deploymentSkuName: modelDeploymentSkuName
    deploymentSkuCapacity: modelDeploymentSkuCapacity
    }
  }

output azoaiResourceId string = azoaiModule.outputs.id
output endpoint string = azoaiModule.outputs.endpoint
output primaryAccessKey string = azoaiModule.outputs.primaryAccessKey
output secondaryAccessKey string = azoaiModule.outputs.secondaryAccessKey
output deployedModelName string = azoaiModule.outputs.deployedModelName
output deployedModelVersion string = azoaiModule.outputs.deployedModelVersion
output deployedModelDeploymentName string = azoaiModule.outputs.deployedModelDeploymentName
