using '../templates/platform-standalone-ai-foundry.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'spoke-ai'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Standalone Foundry RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// i.e. gtc-agentframework-dev-wus2-001-rg
// =====================
param foundryName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-aif'
param projectName = '${productIac}-${environmentIac}'

// Required N-model configuration.
// Allowed modelName values are validated by the template type definition.
param modelDeployments = [
  {
    deploymentName: 'openai-chat'
    modelName: 'gpt-5.4'
    modelFormat: 'OpenAI'
    modelVersion: '2025-04-14'
    skuName: 'Standard'
    skuCapacity: 1
  }
  {
    deploymentName: 'microsoft-reasoning'
    modelName: 'phi-4'
    modelFormat: 'OpenAI'
    modelVersion: '2025-04-14'
    skuName: 'Standard'
    skuCapacity: 1
  }
  {
    deploymentName: 'anthropic-chat'
    modelName: 'claude-sonnet'
    modelFormat: 'OpenAI'
    modelVersion: '2025-04-14'
    skuName: 'Standard'
    skuCapacity: 1
  }
]

// Keep diagnostics off by default for low-friction standalone deployments.
param enableDiagnostics = false
param diagnosticsSettings = {}
