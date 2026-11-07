// Component contract for the digitalproduct archetype.
// Shared by workload-digitalproduct and workload-digitalproduct-zerotrust.
import { planSku as planSkuType, storageSku as storageSkuType } from 'workload-types.bicep'

@export()
@sealed()
type hostingConfig = {
  @minLength(1)
  @maxLength(255)
  @description('Application Insights name. Created in standalone mode; looked up in the shared RG otherwise.')
  appiName: string

  @minLength(1)
  @maxLength(40)
  @description('App Service Plan name. Created in standalone mode; looked up in the shared RG otherwise.')
  planName: string

  @description('Standalone only. App Service Plan SKU.')
  planSku: planSkuType?

  @minLength(4)
  @maxLength(63)
  @description('Required in standalone mode. Log Analytics workspace name backing Application Insights.')
  workspaceName: string?
}

@export()
@sealed()
type webConfig = {
  @minLength(1)
  @maxLength(60)
  @description('Web App name.')
  name: string
}

@export()
@sealed()
type apiConfig = {
  @minLength(1)
  @maxLength(60)
  @description('API App name.')
  name: string

  @minLength(3)
  @maxLength(128)
  @description('Optional workload-owned user-assigned identity. Omit to preserve system-assigned identity.')
  userAssignedIdentityName: string?
}

@export()
@sealed()
type sqlAdministrator = {
  @minLength(1)
  @maxLength(256)
  @description('Display name of the workload-tenant SQL Entra administrator group.')
  login: string

  @minLength(36)
  @maxLength(36)
  @description('Object ID of the SQL Entra administrator, not its application/client ID.')
  objectId: string

  @minLength(36)
  @maxLength(36)
  @description('Workload Entra tenant ID. Independent of the user sign-in/External ID tenant.')
  tenantId: string
}

@sealed()
type sqlEntraServer = {
  kind: 'EntraOnly'
  administrator: sqlAdministrator
}

@sealed()
type sqlPasswordServer = {
  kind: 'SqlAuth'

  @minLength(1)
  @maxLength(128)
  @description('SQL administrator login selected at creation. Password is supplied separately as a secure parameter.')
  administratorLogin: string
}

@sealed()
type sqlExistingServer = {
  kind: 'Existing'

  @description('Expected authentication on the independently owned server. Defaults to EntraOnly; never modified by this deployment.')
  authentication: 'EntraOnly' | 'SqlAuth'?

  @minLength(1)
  @maxLength(90)
  @description('Resource group of the existing server. Its authentication, firewall and administrator are not modified.')
  resourceGroupName: string

  @description('Subscription of the existing server. Defaults to the workload subscription.')
  subscriptionId: string?
}

@export()
@discriminator('kind')
type sqlServerDeployment = sqlEntraServer | sqlPasswordServer | sqlExistingServer

@export()
@sealed()
type sqlConfig = {
  @minLength(1)
  @maxLength(60)
  @description('SQL Server name.')
  serverName: string

  @minLength(1)
  @maxLength(60)
  @description('SQL Database name.')
  databaseName: string

  @description('SQL Database SKU.')
  databaseSku: 'Basic' | 'Standard' | 'Premium'?

  @description('Owned server public network access in standard compositions. Zero-trust compositions force Disabled.')
  publicNetworkAccess: 'Enabled' | 'Disabled'?

  @description('Manage the owned server firewall rule. Zero-trust compositions disable it; referenced servers are untouched.')
  allowAzureServices: bool?

  @minLength(7)
  @maxLength(15)
  @description('Start IPv4 address of the owned server firewall rule. Defaults to 0.0.0.0.')
  startIpAddress: string?

  @minLength(7)
  @maxLength(15)
  @description('End IPv4 address of the owned server firewall rule. Defaults to 0.0.0.0.')
  endIpAddress: string?

  @description('Create an Entra-only or SQL-authentication server, or reference an independently owned server. Owned-server authentication is fixed at creation.')
  server: sqlServerDeployment
}

@export()
@sealed()
type funcConfig = {
  @minLength(1)
  @maxLength(60)
  @description('Function App name.')
  name: string

  @minLength(3)
  @maxLength(24)
  @description('Storage account created in this RG for the Function App. 3-24 lowercase letters and numbers.')
  storageName: string

  @description('Storage account SKU.')
  storageSku: storageSkuType?

  @description('Function worker runtime.')
  runtime: 'dotnet' | 'dotnet-isolated' | 'python'?

  @description('Functions runtime major version.')
  version: 1 | 2 | 3 | 4?

  @description('Keep the Function App always on. Requires a plan above the free and consumption tiers.')
  alwaysOn: bool?
}
