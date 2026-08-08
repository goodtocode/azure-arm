using '../templates/platform-standalone-ai-foundry.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'spoke-ai'
var environmentIac = 'dev'
var regionIac = 'wus'
var instanceIac = '100'
param location = 'westus'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Platform Spoke AI RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
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
    deploymentName: 'openai-fast'
    modelName: 'gpt-4.1-mini'
    modelFormat: 'OpenAI'
    modelVersion: '2025-04-14'
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
