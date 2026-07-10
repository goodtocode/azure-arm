using '../templates/platform-standalone-ai-ollama.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'crucible'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var storageAccountProductIac = take(replace(productIac, '-', ''), 24 - length(environmentIac) - length(regionIac) - length(instanceIac) - 3)
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Spoke AI in SPOKE_MGMT_RG_NAME
// =====================
param environmentName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-acaenv'
param containerAppName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-ollama'
param storageAccountName = '${storageAccountProductIac}${environmentIac}${regionIac}${instanceIac}oll'
param storageShareName = 'ollama-models'

param modelName = 'phi4'
param containerImage = 'ollama/ollama:latest'
param cpuCores = 2
param memoryGiB = '4Gi'
param minReplicas = 1
param maxReplicas = 1
param storageSku = 'Standard_LRS'
