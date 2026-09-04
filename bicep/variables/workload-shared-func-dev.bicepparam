using '../templates/workload-shared-func.bicep'

// Common
var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'

param environmentApp = 'Development'
param location = 'westus2'
param tags = {
  Environment: environmentIac
  CostCenter: '0000'
  project: productIac
  owner: scopeOwner
}

// Existing shared platform services in another resource group in the deployment subscription.
param appiResourceGroupName = '${scopeOwner}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
param appiName = 'spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'
param planResourceGroupName = '${scopeOwner}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
param planName = 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'

// Home resource group resources.
param stAccountName = '${productIac}${environmentIac}${regionIac}${instanceIac}st'
param deployStorage = false
param stSku = 'Standard_LRS'
param funcName = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}-func'
param alwaysOn = true
param use32BitWorkerProcess = true
param funcRuntime = 'dotnet-isolated'
param funcVersion = 4
