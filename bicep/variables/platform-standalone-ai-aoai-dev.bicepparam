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
