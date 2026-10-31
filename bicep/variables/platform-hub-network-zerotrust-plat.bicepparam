using '../templates/platform-hub-network-zerotrust.bicep'

// =====================
// Common
// =====================
var scopeOwner = 'ScopeOrTenant'
var productIac = 'network'
var environmentIac = 'plat'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: scopeOwner
}

// =====================
// Networking RG: ${productIac}-${environmentIac}-${regionIac}-${instanceIac}-rg
// Zero trust hub: Front Door Premium (private link origins) + API Management
// =====================
param afdSku = 'Premium_AzureFrontDoor'
param apimPublisherName = 'Platform Engineering'
param apimPublisherEmail = 'platform@example.com'
param vnetName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-vnet'
param vnetCidr = '10.10.0.0/16'
param snetNameHubShared = '${productIac}-hub-shared-${instanceIac}-snet'
param snetCidrHubShared = '10.10.1.0/24'
param snetNameAzureBastion = '${productIac}-azure-bastion-${instanceIac}-snet'
param snetCidrAzureBastion = '10.10.2.0/24'
