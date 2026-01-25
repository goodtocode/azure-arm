using '../templates/platform-hub-network-publicroute.bicep'

// =====================
// Common
// =====================
var tenantIac = 'COMPANY'
var productIac = 'platform'
var environmentIac = 'prod'
var regionIac = 'wus2'
var instanceIac = '001'
param location = 'West US 2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: tenantIac
}

// =====================
// Networking
// =====================
param afdSku = 'Standard_AzureFrontDoor'
param vnetName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-vnet'
param vnetCidr = '10.10.0.0/16'
param snetNameManagement = '${productIac}-hub-management-${instanceIac}-snet'
param snetCidrManagement = '10.10.1.0/24'
param snetNameAzureBastion = '${productIac}-azure-bastion-${instanceIac}-snet'
param snetCidrAzureBastion = '10.10.2.0/24'
