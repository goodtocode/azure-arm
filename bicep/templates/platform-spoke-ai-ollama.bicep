targetScope = 'resourceGroup'

@description('Azure region for deployment. Defaults to the resource group location.')
param location string = resourceGroup().location

@description('Tags to apply to all deployed resources.')
param tags object = {}

@minLength(3)
@maxLength(63)
@description('Name of the Azure Container Apps managed environment.')
param environmentName string

@minLength(2)
@maxLength(63)
@description('Name of the Container App running Ollama.')
param containerAppName string

@minLength(3)
@maxLength(24)
@description('Name of the Storage Account used for persistent Ollama model storage.')
param storageAccountName string

@minLength(3)
@maxLength(63)
@description('Name of the Azure Files share used for persistent Ollama model storage.')
param storageShareName string = 'ollama-models'

@description('Ollama model to pull and serve on startup.')
@allowed([
  'phi4'
  'phi4-mini'
  'llama3.1'
  'mistral'
  'qwen2.5'
  'gemma2'
])
param modelName string = 'phi4'

@description('Container image for Ollama runtime.')
param containerImage string = 'ollama/ollama:latest'

@description('CPU cores assigned to the Ollama container.')
@allowed([
  1
  2
  4
])
param cpuCores int = 2

@description('Memory assigned to the Ollama container.')
@allowed([
  '2Gi'
  '4Gi'
  '8Gi'
])
param memoryGiB string = '4Gi'

@description('Minimum replica count for Ollama container app.')
@minValue(0)
param minReplicas int = 1

@description('Maximum replica count for Ollama container app.')
@minValue(1)
param maxReplicas int = 1

@description('Storage SKU for persistent model storage account.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storageSku string = 'Standard_LRS'

@description('Resource ID of the delegated subnet used by the Azure Container Apps managed environment infrastructure.')
@minLength(20)
param infrastructureSubnetResourceId string

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetResourceId
      internal: true
    }
  }
}

module ollamaModule '../modules/aca-ollama.bicep' = {
  name: 'ollamaModule'
  dependsOn: [
    managedEnvironment
  ]
  params: {
    location: location
    tags: tags
    managedEnvironmentName: environmentName
    containerAppName: containerAppName
    storageAccountName: storageAccountName
    storageShareName: storageShareName
    modelName: modelName
    containerImage: containerImage
    cpuCores: cpuCores
    memoryGiB: memoryGiB
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    storageSku: storageSku
    ingressExternal: false
    ingressAllowedCidrs: []
  }
}

output ollamaEndpoint string = ollamaModule.outputs.ollamaEndpoint
output deployedModel string = ollamaModule.outputs.deployedModel
output containerAppId string = ollamaModule.outputs.containerAppId
output environmentId string = ollamaModule.outputs.environmentId
