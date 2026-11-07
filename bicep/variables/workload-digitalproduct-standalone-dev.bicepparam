using '../templates/workload-digitalproduct.bicep'

// Mode 1 - Standalone: plan, Log Analytics, App Insights and every component live in this RG.
// Set SQL_ENTRA_ADMIN_GROUP_OBJECT_ID and AZURE_TENANT_ID to the workload tenant's administrator group and tenant.
// Placeholder IDs permit offline compilation only; replace them before deployment.

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
  planName: '${prefix}-F1-asp'
  planSku: 'F1'
  workspaceName: '${prefix}-log'
}

// Components: delete a line to skip that component.
param web = { name: '${prefix}-web' }
param api = { name: '${prefix}-api', userAssignedIdentityName: '${prefix}-api-id' }
param sql = {
  serverName: '${prefix}-sql'
  databaseName: '${prefix}-sqldb'
  databaseSku: 'Basic'
  server: {
    kind: 'EntraOnly'
    administrator: {
      login: 'SQL Administrators'
      objectId: readEnvironmentVariable('SQL_ENTRA_ADMIN_GROUP_OBJECT_ID', '00000000-0000-0000-0000-000000000000')
      tenantId: readEnvironmentVariable('AZURE_TENANT_ID', '00000000-0000-0000-0000-000000000000')
    }
  }
}
param func = {
  name: '${prefix}-func'
  storageName: '${storagePrefix}st'
}
