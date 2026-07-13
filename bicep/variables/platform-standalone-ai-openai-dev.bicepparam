using '../templates/platform-standalone-ai-openai.bicep'

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
// Platform Spoke AI RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// i.e. gtc-spoke-ai-dev-wus2-001
// =====================
param azoaiSku = 'S0'
param azoaiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-azoai'
param deployModel = true
param modelDeploymentName = 'default'
param modelName = 'gpt-5.5'
param modelFormat = 'OpenAI'
param modelVersion = '2026-04-24'
param modelDeploymentSkuName = 'Standard'
param modelDeploymentSkuCapacity = 1
