using '../templates/workload-spoke-func.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Mgmt Resource Group (spoke)
param spokeMgmtResourceGroupName = '${tenantIac}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
param appiName = 'spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'

// Storage
param stName = '${productIac}${environmentIac}${instanceIac}st'
param stSku = 'Standard_LRS'
// Replace with the delegated spoke subnet resource ID used by the Function App.
param storageSubnetResourceId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/spoke-network-dev-wus2-001-rg/providers/Microsoft.Network/virtualNetworks/spoke-dev-wus2-001-vnet/subnets/apps-snet'

// Azure Functions
param funcName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-func'
param planName = 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
param alwaysOn = true

