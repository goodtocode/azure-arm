using '../templates/platform-spoke-ai-foundry.bicep'

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
// Foundry spoke resources
// =====================
param foundryName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-aif'
param projectName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-proj'
param projectDescription = 'Development spoke AI project.'
param privateEndpointName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-aif-pe'

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
]

// Replace these with the subnet and Private DNS zone in this spoke's subscription.
param privateEndpointSubnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/spoke-network-dev-wus2-001-rg/providers/Microsoft.Network/virtualNetworks/spoke-dev-wus2-001-vnet/subnets/private-endpoints-snet'
param privateDnsZoneResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/platform-dns-dev-wus2-001-rg/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com'
