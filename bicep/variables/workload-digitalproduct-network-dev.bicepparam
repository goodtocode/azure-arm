using '../templates/workload-digitalproduct.bicep'

// Mode 3 - Network: mode 2 plus regional VNet integration into an existing spoke subnet.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-digitalproduct.bicep -p bicep/variables/workload-digitalproduct-network-dev.bicepparam

var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'F1'
var prefix = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}'
var storagePrefix = toLower('${productIac}${environmentIac}${regionIac}${instanceIac}')

param mode = 'network'
param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param shared = {
  resourceGroupName: '${scopeOwner}-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
}

param hosting = {
  appiName: 'mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'
  planName: 'mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
}

param vnet = {
  subscriptionId: '00000000-0000-0000-0000-000000000000'
  resourceGroupName: 'spoke-network-${environmentIac}-${regionIac}-${instanceIac}-rg'
  vnetName: 'spoke-${environmentIac}-${regionIac}-${instanceIac}-vnet'
  subnetName: 'spoke-${environmentIac}-apps-snet'
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
