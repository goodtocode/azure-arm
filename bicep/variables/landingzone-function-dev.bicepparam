using '../templates/landingzone-function.bicep'
// Common

var tenantIac = 'COMPANY'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'West US 2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

// Workspace
param mgmtSubscriptionId = '00000000-0000-0000-0000-000000000000'
param mgmtResourceGroupName = '${tenantIac}-spokemgmt-${environmentIac}-${instanceIac}-rg'
param workName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-law'

// Azure Monitor App Insights
param appiName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-appi'

// Storage
param stName = '${productIac}${environmentIac}${regionIac}${instanceIac}st'
param stSku = 'Standard_LRS'

// Key Vault
param kvName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-kv'
param kvSku = 'standard'
param accessPolicies = [
  {
    objectId: 'PIPELINE_PRINCIPLE_OBJECT_ID'
    permissions: {
      secrets: ['Get', 'List']
    }
  }
]

// Azure Functions
param funcName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-func'
param planName = '${productIac}-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
param alwaysOn = true

