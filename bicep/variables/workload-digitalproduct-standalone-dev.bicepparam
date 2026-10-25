using '../templates/workload-digitalproduct.bicep'

// Mode 1 - Standalone: plan, Log Analytics, App Insights and every component live in this RG.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-digitalproduct.bicep -p bicep/variables/workload-digitalproduct-standalone-dev.bicepparam   (set $env:SQL_ADMIN_PASSWORD first)

var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var prefix = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}'
var storagePrefix = toLower('${productIac}${environmentIac}${regionIac}${instanceIac}')

param mode = 'standalone'
param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param hosting = {
  appiName: '${prefix}-appi'
  planName: '${prefix}-F1-plan'
  planSku: 'F1'
  workspaceName: '${prefix}-work'
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
