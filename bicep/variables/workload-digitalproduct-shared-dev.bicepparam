using '../templates/workload-digitalproduct.bicep'

// Mode 2 - Shared: the product installs in this RG and reuses the plan and App Insights from the spoke mgmt RG (same subscription).
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-digitalproduct.bicep -p bicep/variables/workload-digitalproduct-shared-dev.bicepparam

var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'
var prefix = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}'
var storagePrefix = toLower('${productIac}${environmentIac}${regionIac}${instanceIac}')

param mode = 'shared'
param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param shared = {
  resourceGroupName: 'mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
}

param hosting = {
  appiName: 'mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'
  planName: 'mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
}

// Components: delete a line to skip that component.
param web = { name: '${prefix}-web' }
param api = { name: '${prefix}-api' }
param sql = {
  serverName: '${prefix}-sql'
  databaseName: '${prefix}-sqldb'
  databaseSku: 'Basic'
  adminLogin: 'LocalAdmin'
  adminPassword: readEnvironmentVariable('SQL_ADMIN_PASSWORD', 'PASS_FROM_CLI_PARAMETERS')
}
param func = {
  name: '${prefix}-func'
  storageName: '${storagePrefix}st'
}
