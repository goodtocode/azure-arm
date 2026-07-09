using '../templates/platform-standalone-ai-ollama.bicep'

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
// Standalone Ollama RG: ${tenantIac}-${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// i.e. company-crucible-dev-wus2-001-rg
// =====================
param environmentName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-acaenv'
param containerAppName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-ollama'
param storageAccountName = 'cru${environmentIac}${regionIac}${instanceIac}oll'
param storageShareName = 'ollama-models'

param modelName = 'phi4'
param containerImage = 'ollama/ollama:latest'
param cpuCores = 2
param memoryGiB = '4Gi'
param minReplicas = 1
param maxReplicas = 1
param storageSku = 'Standard_LRS'
