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
    deploymentName: 'openai-chat'
    modelName: 'gpt-5.4'
    modelFormat: 'OpenAI'
    modelVersion: '2026-03-05'
    skuName: 'GlobalStandard'
    tokensPerMinute: 20000
  }
  {
    deploymentName: 'ms-fast'
    modelName: 'mai-code-1.1-flash'
    modelFormat: 'Microsoft'
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
