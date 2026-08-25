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
param projectDescription string = 'Spoke Azure AI Foundry project.'

type FoundryModelName =
  | 'claude-opus'
  | 'claude-sonnet'
  | 'gpt-5.4'
  | 'gpt-5.3-chat'
  | 'gpt-5.3-codex'
  | 'gpt-4.1'
  | 'gpt-4.1-mini'
  | 'Phi-4'
  | 'MAI-Image-2'
  | 'MAI-Image-2.5'
  | 'MAI-Image-2.5-Flash'
  | 'MAI-Image-2.5-Pro'
  | 'MAI-Image-2e'

type FoundryDeploymentConfig = {
  deploymentName: string
  modelName: FoundryModelName
  modelFormat: 'OpenAI' | 'Microsoft'
  modelVersion: string?
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

@minLength(20)
@description('Resource ID of the subnet in this spoke used for the Foundry private endpoint.')
param privateEndpointSubnetResourceId string

@minLength(20)
@description('Resource ID of the Private DNS zone for the Foundry private endpoint, normally privatelink.cognitiveservices.azure.com.')
param privateDnsZoneResourceId string

@description('Name of the private endpoint resource.')
@minLength(1)
@maxLength(80)
param privateEndpointName string

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
    networkDefaultAction: 'Deny'
    publicNetworkAccess: 'Disabled'
    disableLocalAuth: true
  }
}

resource foundryPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: aifModule.outputs.resourceId
          groupIds: [
            'account'
          ]
        }
      }
    ]
  }
}

resource foundryPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: foundryPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'cognitiveservices'
        properties: {
          privateDnsZoneId: privateDnsZoneResourceId
        }
      }
    ]
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

@description('Resource ID of the Foundry private endpoint.')
output privateEndpointResourceId string = foundryPrivateEndpoint.id
