targetScope = 'resourceGroup'

import { sqlConfig } from '../types/digitalproduct-types.bicep'

@description('SQL server ownership/authentication and product database configuration.')
param sql sqlConfig

@description('Region for a newly owned server/database. An existing-server database uses its server region.')
param location string

@description('Resource tags for owned resources.')
param tags object = {}

@description('Public network access for a newly owned server. An existing server is never modified.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Allow Azure IP addresses on a newly owned server. An existing server is never modified.')
param allowAzureServices bool = true

var existing = sql.server.kind == 'Existing'
var serverSubscriptionId = sql.server.?subscriptionId ?? subscription().subscriptionId
var serverResourceGroupName = sql.server.?resourceGroupName ?? resourceGroup().name

module serverModule 'sql-sqlserver.bicep' = if (!existing) {
  name: 'server'
  params: {
    name: sql.serverName
    location: location
    tags: tags
    entraAdministrator: sql.server.?administrator!
    publicNetworkAccess: publicNetworkAccess
    allowAzureServices: allowAzureServices
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
output serverKind string = sql.server.kind
