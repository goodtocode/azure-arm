using '../templates/platform-standalone-ai-aoai.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'spoke-ai'
var environmentIac = 'dev'
var regionIac = 'wus'
var instanceIac = '001'
param location = 'westus' // westus2 does not support Azure OpenAI yet
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Platform Spoke AI RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// i.e. gtc-spoke-ai-dev-wus-001
// =====================
param azoaiSku = 'S0'
param azoaiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-azoai'

// Use the new N-model deployment shape in the existing AOAI pipeline path.
param deployModel = true
param modelDeployments = [
  {
    deploymentName: 'openai-chat'
    modelName: 'gpt-5.4'
    modelFormat: 'OpenAI'
    modelVersion: '2026-03-05'
    modelDeploymentSkuName: 'Standard'
    modelDeploymentSkuCapacity: 1
  }
  {
    deploymentName: 'openai-fast'
    modelName: 'gpt-4o-mini'
    modelFormat: 'OpenAI'
    modelVersion: '2024-07-18'
    modelDeploymentSkuName: 'Standard'
    modelDeploymentSkuCapacity: 1
  }
]
