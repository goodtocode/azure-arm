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
  @description('Standalone only. Log Analytics workspace name backing Application Insights.')
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
}

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

  @minLength(1)
  @maxLength(60)
  @description('SQL Server administrator login.')
  adminLogin: string

  @secure()
  @minLength(8)
  @maxLength(60)
  @description('SQL Server administrator password. Supply from the command line or a secret store, never from a checked-in file.')
  adminPassword: string
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
