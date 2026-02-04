using '../templates/landingzone-func.bicep'
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

// Azure Functions
param funcName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-func'
param planName = 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
param alwaysOn = true

