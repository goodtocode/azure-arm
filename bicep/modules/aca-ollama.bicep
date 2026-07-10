@description('Azure region for all Ollama resources.')
param location string

@description('Tags to apply to Ollama resources.')
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
@description('Name of the Storage Account used for persistent Ollama model storage. Must be globally unique, lowercase letters and numbers only.')
param storageAccountName string

@minLength(3)
@maxLength(63)
@description('Name of the Azure Files share mounted into Ollama for persistent model data.')
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

@description('Container port for Ollama HTTP API.')
@allowed([
  11434
])
param targetPort int = 11434

@description('Storage SKU for the persistent storage account.')
@allowed([
  'Standard_LRS'
  'Standard_ZRS'
])
param storageSku string = 'Standard_LRS'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: empty(tags) ? null : tags
  sku: {
    name: storageSku
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
  }
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource storageShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: storageShareName
  properties: {
    accessTier: 'TransactionOptimized'
    enabledProtocols: 'SMB'
  }
}

resource managedEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: empty(tags) ? null : tags
}

resource environmentStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: managedEnvironment
  name: 'ollamastorage'
  properties: {
    azureFile: {
      accountName: storageAccount.name
      accountKey: storageAccount.listKeys().keys[0].value
      accessMode: 'ReadWrite'
      shareName: storageShareName
    }
  }
}

resource ollamaApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    managedEnvironmentId: managedEnvironment.id
    configuration: {
      ingress: {
        external: false
        targetPort: targetPort
        transport: 'auto'
        allowInsecure: false
      }
      activeRevisionsMode: 'Single'
    }
    template: {
      containers: [
        {
          name: 'ollama'
          image: containerImage
          env: [
            {
              name: 'OLLAMA_HOST'
              value: '0.0.0.0'
            }
            {
              name: 'OLLAMA_MODELS'
              value: '/root/.ollama'
            }
          ]
          command: [
            'sh'
          ]
          args: [
            '-c'
            'ollama serve & until ollama list >/dev/null 2>&1; do sleep 2; done; ollama pull ${modelName}; wait'
          ]
          resources: {
            cpu: cpuCores
            memory: memoryGiB
          }
          volumeMounts: [
            {
              volumeName: 'ollamamodels'
              mountPath: '/root/.ollama'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'ollamamodels'
          storageType: 'AzureFile'
          storageName: environmentStorage.name
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
}

output ollamaEndpoint string = 'http://${ollamaApp.properties.configuration.ingress.fqdn}'
output deployedModel string = modelName
output containerAppId string = ollamaApp.id
output environmentId string = managedEnvironment.id
