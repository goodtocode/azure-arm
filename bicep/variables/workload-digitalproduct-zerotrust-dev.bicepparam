using '../templates/workload-digitalproduct-zerotrust.bicep'

// Mode 4 - Zero trust: mode 3 plus private endpoints, Private DNS and public access disabled.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-digitalproduct-zerotrust.bicep -p bicep/variables/workload-digitalproduct-zerotrust-dev.bicepparam
// Deploy from a runner inside the VNet: the apps and SQL are not reachable from the public internet.

var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var planSku = 'P1'
var prefix = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}'
var storagePrefix = toLower('${productIac}${environmentIac}${regionIac}${instanceIac}')
var networkSubscriptionId = '00000000-0000-0000-0000-000000000000'
var dnsResourceGroup = '${scopeOwner}-hub-network-${regionIac}-${instanceIac}-rg'
var dnsPrefix = '/subscriptions/${networkSubscriptionId}/resourceGroups/${dnsResourceGroup}/providers/Microsoft.Network/privateDnsZones'

param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param shared = {
  resourceGroupName: '${scopeOwner}-spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-rg'
}

param hosting = {
  appiName: 'spoke-mgmt-${environmentIac}-${regionIac}-${instanceIac}-appi'
  planName: 'spoke-mgmt-${environmentIac}-${regionIac}-${planSku}-${instanceIac}-plan'
}

param vnet = {
  subscriptionId: networkSubscriptionId
  resourceGroupName: 'spoke-network-${environmentIac}-${regionIac}-${instanceIac}-rg'
  vnetName: 'spoke-${environmentIac}-${regionIac}-${instanceIac}-vnet'
  subnetName: 'spoke-${environmentIac}-apps-snet'
}

param privateEndpoints = {
  subnetName: 'spoke-${environmentIac}-pe-snet'
  dnsZones: {
    sites: '${dnsPrefix}/privatelink.azurewebsites.net'
    sql: '${dnsPrefix}/privatelink.database.windows.net'
    blob: '${dnsPrefix}/privatelink.blob.core.windows.net'
    file: '${dnsPrefix}/privatelink.file.core.windows.net'
    queue: '${dnsPrefix}/privatelink.queue.core.windows.net'
    table: '${dnsPrefix}/privatelink.table.core.windows.net'
  }
}

// Components: delete a line to skip that component. Omit the matching DNS zones you do not need.
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
