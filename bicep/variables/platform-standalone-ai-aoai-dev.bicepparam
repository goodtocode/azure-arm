using '../templates/platform-standalone-ai-aoai.bicep'

// =====================
// Common
// =====================
var tenantIac = 'aacn'
var productIac = 'devtest-ai'
var environmentIac = 'dev'
var regionIac = 'westus'
var instanceIac = '001'
param location = 'westus' // westus2 does not support Azure OpenAI yet
param tags = {
  Environment: environmentIac
  CostCenter: '1912-51210'
  project: productIac
  owner: tenantIac
}

// =====================
// Platform Standalone AI RG: rg-${productIac}-${environmentIac}-${regionIac}-${instanceIac}
// i.e. rg-devtest-ai-dev-westus2-001
// =====================
param azoaiSku = 'S0'
param azoaiName = 'aoai-${productIac}-${environmentIac}-${regionIac}-${instanceIac}'

// Required model deployments for Azure OpenAI.
param modelDeployments = [
  {
    deploymentName: 'openai-chat'
    modelName: 'gpt-5.4'
    modelFormat: 'OpenAI'
    modelVersion: '2026-03-05'
    deploymentSkuName: 'Standard'
    deploymentSkuCapacity: 1
  }
  {
    deploymentName: 'openai-fast'
    modelName: 'gpt-4o-mini'
    modelFormat: 'OpenAI'
    modelVersion: '2024-07-18'
    deploymentSkuName: 'Standard'
    deploymentSkuCapacity: 1
  }
]
