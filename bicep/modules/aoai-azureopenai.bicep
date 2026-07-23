@description('Name of the Azure OpenAI instance. Must be globally unique and 3-63 characters, using only lowercase letters, numbers, and hyphens, starting and ending with a letter or number.')
@minLength(3)
@maxLength(63)
param name string

@description('Location for the Azure OpenAI resource.')
param location string

@description('Tags to apply to the Azure OpenAI resource.')
param tags object = {}

@description('SKU for Azure OpenAI. Allowed values: S0, Default is S0.')
@allowed([
  'S0'
])
param sku string = 'S0'

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

resource azoaiResource 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: {
    name: sku
  }
  properties: {
    apiProperties: {  
      enableDynamicThrottling: true
    }
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for model in modelDeployments: {
  parent: azoaiResource
  name: model.deploymentName
  sku: {
    name: model.deploymentSkuName
    capacity: int(model.deploymentSkuCapacity)
  }
  properties: {
    model: {
      format: model.modelFormat
      name: model.modelName
      version: model.modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.Default'
  }
}]

output id string =  azoaiResource.id
output endpoint string = azoaiResource.properties.endpoint
#disable-next-line outputs-should-not-contain-secrets
output primaryAccessKey string = azoaiResource.listKeys().key1
#disable-next-line outputs-should-not-contain-secrets
output secondaryAccessKey string = azoaiResource.listKeys().key2
output deployedModelName string = modelDeployments[0].modelName
output deployedModelVersion string = modelDeployments[0].modelVersion
output deployedModelDeploymentName string = modelDeployment[0].name
output deployedModelNames array = [for model in modelDeployments: model.modelName]
output deployedModelVersions array = [for model in modelDeployments: model.modelVersion]
output deployedModelDeploymentNames array = [for i in range(0, length(modelDeployments)): modelDeployment[i].name]
