using '../templates/platform-spoke-ai-ollama.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'platform'
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
param infrastructureSubnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/hub-network-dev-wus2-001-rg/providers/Microsoft.Network/virtualNetworks/hub-dev-wus2-001-vnet/subnets/aca-infra-snet'
