
@description('The name of the SQL Server. Must be 1-60 characters, using only alphanumeric characters and hyphens.')
@minLength(1)
@maxLength(60)
param name string

@description('The Azure region where the SQL Server will be deployed.')
param location string = resourceGroup().location

@description('Tags to apply to the SQL Server resource.')
param tags object = {}

@description('Deployment-owner-selected administrator group in the workload tenant.')
param entraAdministrator {
  login: string
  objectId: string
  tenantId: string
}?

@description('Authentication selected at creation. Changing modes requires a replacement server.')
@allowed(['EntraOnly', 'SqlAuth'])
param authentication string = 'EntraOnly'

@description('Create a server with authentication settings. Set false for existing servers; Entra administrator group is reconciled without changing authentication mode.')
param createServer bool = true

@description('SQL administrator login. Required when creating a SqlAuth server; immutable afterward.')
param sqlAdministratorLogin string = ''

@secure()
@description('SQL administrator password. Required only when creating a SqlAuth server.')
param sqlAdministratorPassword string = ''

@description('Public network access. Private-only compositions explicitly disable it.')
@allowed(['Enabled', 'Disabled'])
param publicNetworkAccess string = 'Enabled'

@description('Allow connections from Azure IP addresses. Does not authorize database access.')
param allowAzureServices bool = true

@description('The starting IP address for the SQL Server firewall rule. Default is 0.0.0.0.')
param startIpAddress string = '0.0.0.0'

@description('The ending IP address for the SQL Server firewall rule. Default is 0.0.0.0.')
param endIpAddress string = '0.0.0.0'


var nameLower = toLower(name)

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: nameLower
  location: location  
  tags: empty(tags) ? null : tags  
  properties: union({
    publicNetworkAccess: publicNetworkAccess
  }, !createServer ? {} : authentication == 'SqlAuth' ? {
    administratorLogin: sqlAdministratorLogin
    administratorLoginPassword: sqlAdministratorPassword
  } : {
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'Group'
      login: entraAdministrator!.login
      sid: entraAdministrator!.objectId
      tenantId: entraAdministrator!.tenantId
      azureADOnlyAuthentication: true
    }
  })
}

resource sqlServerEntraAdministrator 'Microsoft.Sql/servers/administrators@2023-08-01-preview' = if (!createServer && authentication == 'EntraOnly') {
  parent: sqlServer
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: entraAdministrator!.login
    sid: entraAdministrator!.objectId
    tenantId: entraAdministrator!.tenantId
  }
}

resource sqlServerFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = if (allowAzureServices) {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: endIpAddress
    startIpAddress: startIpAddress
  }
}

@description('SQL logical server resource ID.')
output id string = sqlServer.id

@description('SQL logical server name.')
output name string = sqlServer.name

@description('SQL server fully qualified domain name.')
output fullyQualifiedDomainName string = sqlServer.properties.fullyQualifiedDomainName
