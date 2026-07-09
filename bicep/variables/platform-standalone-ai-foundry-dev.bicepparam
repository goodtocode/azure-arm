using '../templates/platform-standalone-ai-foundry.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'crucible'
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
// i.e. company-crucible-dev-wus2-001-rg
// =====================
param foundryName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-aif'
param projectName = '${productIac}-${environmentIac}'
param modelName = 'phi-4'
param deploymentName = 'default'
param skuName = 'Standard'
param modelFormat = 'OpenAI'
param modelVersion = '2025-04-14'
param skuCapacity = 1

// Keep diagnostics off by default for low-friction standalone deployments.
param enableDiagnostics = false
param diagnosticsSettings = {}
