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

@description('When true, deploys a model deployment into the Azure OpenAI account.')
param deployModel bool = true

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

@description('Optional list of model deployments. When provided, one deployment is created per item. If empty, legacy single-model parameters are used when deployModel is true.')
param modelDeployments AoaiDeploymentConfig[] = []

@description('Deployment name clients use at runtime. This is the value used as model/deployment identifier by most Azure OpenAI SDK calls.')
@minLength(1)
@maxLength(64)
param deploymentName string = 'default'

@description('Model name to deploy when deployModel is true.')
@allowed([
  'gpt-5.6-sol'
  'gpt-5.6-terra'
  'gpt-5.6-luna'
  'gpt-5.5'
  'gpt-5.4'
  'gpt-5.4-mini'
  'gpt-5.4-nano'
  'gpt-5.4-pro'
  'gpt-5'
  'gpt-5-mini'
  'gpt-5-nano'
  'gpt-4.1'
  'gpt-4.1-mini'
  'gpt-4.1-nano'
  'gpt-4o'
  'gpt-4o-mini'
  'text-embedding-3-large'
  'text-embedding-3-small'
])
param modelName string = 'gpt-5.5'

@description('Model format required by Azure OpenAI deployment.')
@allowed([
  'OpenAI'
])
param modelFormat string = 'OpenAI'

@description('Model version. Keep configurable because availability varies by region and subscription.')
param modelVersion string = '2026-04-24'

@description('Model deployment SKU name.')
@allowed([
  'Standard'
  'GlobalStandard'
])
param deploymentSkuName string = 'Standard'

@description('Model deployment SKU capacity.')
@minValue(1)
param deploymentSkuCapacity int = 1

var effectiveModelDeployments = !empty(modelDeployments)
  ? modelDeployments
  : (deployModel
      ? [
          {
            deploymentName: deploymentName
            modelName: modelName
            modelFormat: modelFormat
            modelVersion: modelVersion
            deploymentSkuName: deploymentSkuName
            deploymentSkuCapacity: deploymentSkuCapacity
          }
        ]
      : [])

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

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for model in effectiveModelDeployments: {
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
output deployedModelName string = !empty(effectiveModelDeployments) ? effectiveModelDeployments[0].modelName : ''
output deployedModelVersion string = !empty(effectiveModelDeployments) ? effectiveModelDeployments[0].modelVersion : ''
output deployedModelDeploymentName string = !empty(effectiveModelDeployments) ? modelDeployment[0].name : ''
output deployedModelNames array = [for model in effectiveModelDeployments: model.modelName]
output deployedModelVersions array = [for model in effectiveModelDeployments: model.modelVersion]
output deployedModelDeploymentNames array = [for i in range(0, length(effectiveModelDeployments)): modelDeployment[i].name]
