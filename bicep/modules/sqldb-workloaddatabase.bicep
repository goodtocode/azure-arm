targetScope = 'resourceGroup'

import { sqlConfig } from '../types/digitalproduct-types.bicep'

@description('SQL server ownership/authentication and product database configuration.')
param sql sqlConfig

@description('Region for a newly owned server/database. An existing-server database uses its server region.')
param location string

@description('Resource tags for owned resources.')
param tags object = {}

@description('Create the owned server. Set false for existing servers; authentication mode stays unchanged and the Entra administrator group is reconciled.')
param createServer bool = true

@secure()
@description('Password used only to create a SqlAuth server. Never included in the component configuration or outputs.')
param sqlAdministratorPassword string = ''

@description('Optional SQL administrator login supplied by the deployment secret. Used only for SqlAuth server creation.')
param sqlAdministratorLogin string = ''

@description('Optional creation-time authentication override. Empty preserves the typed component choice; existing servers are never converted.')
@allowed(['', 'EntraOnly', 'SqlAuth'])
param sqlAuthentication string = ''

@description('Public network access for a newly owned server. An existing server is never modified.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Allow Azure IP addresses on a newly owned server. An existing server is never modified.')
param allowAzureServices bool = true

var existing = sql.server.kind == 'Existing'
var ownedAuthentication = empty(sqlAuthentication) ? sql.server.kind : sqlAuthentication
var serverSubscriptionId = sql.server.?subscriptionId ?? subscription().subscriptionId
var serverResourceGroupName = sql.server.?resourceGroupName ?? resourceGroup().name

module serverModule 'sql-sqlserver.bicep' = if (!existing) {
  name: 'server'
  params: {
    name: sql.serverName
    location: location
    tags: tags
    entraAdministrator: sql.server.?administrator
    authentication: ownedAuthentication == 'SqlAuth' ? 'SqlAuth' : 'EntraOnly'
    createServer: createServer
    sqlAdministratorLogin: empty(sqlAdministratorLogin) ? (sql.server.?administratorLogin ?? '') : sqlAdministratorLogin
    sqlAdministratorPassword: sqlAdministratorPassword
    publicNetworkAccess: publicNetworkAccess
    allowAzureServices: allowAzureServices
    startIpAddress: sql.?startIpAddress ?? '0.0.0.0'
    endIpAddress: sql.?endIpAddress ?? '0.0.0.0'
  }
}

resource serverExisting 'Microsoft.Sql/servers@2023-08-01-preview' existing = if (existing) {
  name: sql.serverName
  scope: resourceGroup(serverSubscriptionId, serverResourceGroupName)
}

module databaseModule 'sqldb-sqldatabase.bicep' = {
  name: 'database'
  scope: resourceGroup(serverSubscriptionId, serverResourceGroupName)
  params: {
    name: sql.databaseName
    sqlName: existing ? serverExisting!.name : serverModule!.outputs.name
    location: existing ? serverExisting!.location : location
    tags: tags
    sku: sql.?databaseSku ?? 'Basic'
  }
}

@description('Created or referenced SQL logical server resource ID.')
output serverResourceId string = existing ? serverExisting!.id : serverModule!.outputs.id

@description('SQL logical server name.')
output serverName string = existing ? serverExisting!.name : serverModule!.outputs.name

@description('SQL server fully qualified domain name.')
output serverFullyQualifiedDomainName string = existing ? serverExisting!.properties.fullyQualifiedDomainName : serverModule!.outputs.fullyQualifiedDomainName

@description('SQL database resource ID. Only this database is managed on an existing server.')
output databaseResourceId string = databaseModule.outputs.id

@description('SQL database name.')
output databaseName string = databaseModule.outputs.name

@description('Server authentication/ownership choice. Existing-server authentication must be checked before bootstrap.')
output serverKind string = existing ? (sql.server.?authentication ?? 'EntraOnly') : ownedAuthentication
