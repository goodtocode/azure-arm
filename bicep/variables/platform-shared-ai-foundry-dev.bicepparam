using '../templates/platform-shared-ai-foundry.bicep'

// =====================
// Common
// =====================
var scopeOwner = 'ScopeOrTenant'
var productIac = 'spoke-ai'
var environmentIac = 'dev'
var regionIac = 'wus'
var instanceIac = '100'
param location = 'westus'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: scopeOwner
}

// =====================
// Platform Spoke AI RG: ${scopeOwner}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// =====================
param foundryName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-aif'
param projectName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-proj'
param projectDescription = 'Development spoke AI project.'

// Required model deployments for Azure AI Foundry.
param modelDeployments = [
  {
    deploymentName: 'ms-thinking'
    modelName: 'MAI-Thinking-1'
    modelFormat: 'Microsoft'
    modelVersion: '2026-06-01'
    skuName: 'GlobalStandard'
    tokensPerMinute: 20000
  }
  {
    deploymentName: 'ms-fast'
    modelName: 'Phi-4-mini-instruct'
    modelFormat: 'Microsoft'
    modelVersion: '1'
    skuName: 'GlobalStandard'
    tokensPerMinute: 20000
  }
  {
    deploymentName: 'embedding-fast'
    modelName: 'text-embedding-3-small'
    modelFormat: 'OpenAI'
    skuName: 'GlobalStandard'
    tokensPerMinute: 20000
  }
  {
    deploymentName: 'ms-chat'
    modelName: 'Phi-4'
    modelFormat: 'Microsoft'
    modelVersion: '7'
    skuName: 'GlobalStandard'
    tokensPerMinute: 10000
  }
  {
    deploymentName: 'mai-image'
    modelName: 'MAI-Image-2.5-Flash'
    modelFormat: 'Microsoft'
    modelVersion: '2026-06-02'
    skuName: 'GlobalStandard'
    tokensPerMinute: 2000
  }
]
