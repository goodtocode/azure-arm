// =============================================================================
// workload-digitalproduct-zerotrust
// Archetype : Digital product (web, API, SQL, Function App in any combination)
// Mode      : zerotrust (mode 4). Everything is reached through private endpoints.
//   - The plan and App Insights come from the shared RG (same subscription).
//   - Apps are VNet integrated, route all outbound traffic through the VNet,
//     and have public network access disabled.
//   - SQL and the Function App storage have public access disabled.
//   - One private endpoint per app, SQL server, and storage sub-resource is created
//     in the home RG on an existing private endpoint subnet and registered in
//     existing Private DNS zones.
// Prerequisites (platform-owned): VNet, an integration subnet delegated to
//   Microsoft.Web/serverFarms, a private endpoint subnet, the Private DNS zones
//   listed in privateEndpoints.dnsZones linked to the VNet, and a plan SKU that
//   supports private endpoints (Basic or higher).
// Not covered: Application Insights ingestion over Private Link, Entra-only SQL
//   authentication, and inbound routing through Front Door or Application Gateway.
// Variables : bicep/variables/workload-digitalproduct-zerotrust-<env>.bicepparam
// =============================================================================
targetScope = 'resourceGroup'

import { workloadRegion, sharedRef, vnetRef } from '../types/workload-types.bicep'
import { hostingConfig, webConfig, apiConfig, sqlConfig, funcConfig } from '../types/digitalproduct-types.bicep'

@sealed()
type dnsZoneIds = {
  @description('Private DNS zone resource ID for privatelink.azurewebsites.net. Required with web, api, or func.')
  sites: string?

  @description('Private DNS zone resource ID for privatelink.database.windows.net. Required with sql.')
  sql: string?

  @description('Private DNS zone resource ID for privatelink.blob.core.windows.net. Required with func.')
  blob: string?

  @description('Private DNS zone resource ID for privatelink.file.core.windows.net. Required with func.')
  file: string?

  @description('Private DNS zone resource ID for privatelink.queue.core.windows.net. Required with func.')
  queue: string?

  @description('Private DNS zone resource ID for privatelink.table.core.windows.net. Required with func.')
  table: string?
}

@sealed()
type privateEndpointConfig = {
  @minLength(1)
  @maxLength(80)
  @description('Subnet in the VNet referenced by vnet that hosts the private endpoints.')
  subnetName: string

  @description('Existing Private DNS zones that receive the endpoint records.')
  dnsZones: dnsZoneIds
}

@description('Azure region for all resources in this deployment. Must match the VNet region.')
param location workloadRegion

@description('Resource tags applied to every resource.')
param tags object

@minLength(1)
@maxLength(40)
@description('Application environment name passed to the apps (for example Development, Production).')
param environmentApp string

@description('Plan and Application Insights names in the shared RG. Standalone-only settings are ignored.')
param hosting hostingConfig

@description('Shared RG holding the plan and Application Insights.')
param shared sharedRef

@description('Existing VNet and the integration subnet used by the apps.')
param vnet vnetRef

@description('Private endpoint subnet and Private DNS zones.')
param privateEndpoints privateEndpointConfig

@description('Web App. Omit to skip.')
param web webConfig?

@description('API App. Omit to skip.')
param api apiConfig?

@description('SQL Server and Database. Omit to skip.')
param sql sqlConfig?

@description('Function App and its storage account. Omit to skip.')
param func funcConfig?

var hasWeb = web != null
var hasApi = api != null
var hasSql = sql != null
var hasFunc = func != null
var sharedSubscriptionId = shared.?subscriptionId ?? subscription().subscriptionId
var vnetSubscriptionId = vnet.?subscriptionId ?? subscription().subscriptionId

resource appiShared 'Microsoft.Insights/components@2020-02-02' existing = {
  name: hosting.appiName
  scope: resourceGroup(sharedSubscriptionId, shared.resourceGroupName)
}

resource planShared 'Microsoft.Web/serverfarms@2023-01-01' existing = {
  name: hosting.planName
  scope: resourceGroup(sharedSubscriptionId, shared.resourceGroupName)
}

resource integrationSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = {
  name: '${vnet.vnetName}/${vnet.subnetName}'
  scope: resourceGroup(vnetSubscriptionId, vnet.resourceGroupName)
}

resource endpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = {
  name: '${vnet.vnetName}/${privateEndpoints.subnetName}'
  scope: resourceGroup(vnetSubscriptionId, vnet.resourceGroupName)
}

var routeAllEnabled = vnet.?routeAllEnabled ?? true
var imagePullEnabled = vnet.?imagePullEnabled ?? false
var backupRestoreEnabled = vnet.?backupRestoreEnabled ?? false

module apiModule '../modules/api-appservice.bicep' = if (hasApi) {
  name: 'digitalproduct-zt-api'
  params: {
    name: api!.name
    location: location
    tags: tags
    environment: environmentApp
    appiKey: appiShared.properties.InstrumentationKey
    appiConnection: appiShared.properties.ConnectionString
    planId: planShared.id
    subnetId: integrationSubnet.id
    publicNetworkAccess: 'Disabled'
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: true
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
}

module apiEndpoint '../modules/pe-privateendpoint.bicep' = if (hasApi) {
  name: 'digitalproduct-zt-api-pe'
  params: {
    name: '${api!.name}-pe'
    location: location
    tags: tags
    subnetId: endpointSubnet.id
    targetResourceId: apiModule!.outputs.id
    groupId: 'sites'
    privateDnsZoneId: privateEndpoints.dnsZones.sites!
  }
}

module webModule '../modules/web-appservice.bicep' = if (hasWeb) {
  name: 'digitalproduct-zt-web'
  params: {
    name: web!.name
    location: location
    tags: tags
    environment: environmentApp
    appiKey: appiShared.properties.InstrumentationKey
    appiConnection: appiShared.properties.ConnectionString
    planId: planShared.id
    subnetId: integrationSubnet.id
    publicNetworkAccess: 'Disabled'
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: true
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
}

module webEndpoint '../modules/pe-privateendpoint.bicep' = if (hasWeb) {
  name: 'digitalproduct-zt-web-pe'
  params: {
    name: '${web!.name}-pe'
    location: location
    tags: tags
    subnetId: endpointSubnet.id
    targetResourceId: webModule!.outputs.id
    groupId: 'sites'
    privateDnsZoneId: privateEndpoints.dnsZones.sites!
  }
}

module sqlModule '../modules/sql-sqlserverdatabase.bicep' = if (hasSql) {
  name: 'digitalproduct-zt-sql'
  params: {
    name: sql!.serverName
    location: location
    tags: tags
    adminLogin: sql!.adminLogin
    adminPassword: sql!.adminPassword
    sqldbName: sql!.databaseName
    sku: sql.?databaseSku ?? 'Basic'
    publicNetworkAccess: 'Disabled'
    allowAzureServices: false
  }
}

module sqlEndpoint '../modules/pe-privateendpoint.bicep' = if (hasSql) {
  name: 'digitalproduct-zt-sql-pe'
  params: {
    name: '${sql!.serverName}-pe'
    location: location
    tags: tags
    subnetId: endpointSubnet.id
    targetResourceId: sqlModule!.outputs.id
    groupId: 'sqlServer'
    privateDnsZoneId: privateEndpoints.dnsZones.sql!
  }
}

module storageModule '../modules/st-storageaccount.bicep' = if (hasFunc) {
  name: 'digitalproduct-zt-st'
  params: {
    name: func!.storageName
    location: location
    tags: tags
    sku: func.?storageSku ?? 'Standard_LRS'
    publicNetworkAccess: 'Disabled'
    networkDefaultAction: 'Deny'
  }
}

var storageGroups = [
  { groupId: 'blob', zone: privateEndpoints.dnsZones.?blob }
  { groupId: 'file', zone: privateEndpoints.dnsZones.?file }
  { groupId: 'queue', zone: privateEndpoints.dnsZones.?queue }
  { groupId: 'table', zone: privateEndpoints.dnsZones.?table }
]

module storageEndpoints '../modules/pe-privateendpoint.bicep' = [for g in storageGroups: if (hasFunc) {
  name: 'digitalproduct-zt-st-${g.groupId}-pe'
  params: {
    name: '${func!.storageName}-${g.groupId}-pe'
    location: location
    tags: tags
    subnetId: endpointSubnet.id
    targetResourceId: storageModule!.outputs.id
    groupId: g.groupId
    privateDnsZoneId: g.zone!
  }
}]

module funcModule '../modules/func-functionsapp.bicep' = if (hasFunc) {
  name: 'digitalproduct-zt-func'
  params: {
    name: func!.name
    location: location
    tags: tags
    environmentApp: environmentApp
    appiKey: appiShared.properties.InstrumentationKey
    appiConnection: appiShared.properties.ConnectionString
    planId: planShared.id
    stName: func!.storageName
    funcRuntime: func.?runtime ?? 'dotnet-isolated'
    funcVersion: func.?version ?? 4
    alwaysOn: func.?alwaysOn ?? false
    subnetId: integrationSubnet.id
    publicNetworkAccess: 'Disabled'
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: true
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
  // The Function App reads its content share over the private endpoints.
  dependsOn: [storageEndpoints]
}

module funcEndpoint '../modules/pe-privateendpoint.bicep' = if (hasFunc) {
  name: 'digitalproduct-zt-func-pe'
  params: {
    name: '${func!.name}-pe'
    location: location
    tags: tags
    subnetId: endpointSubnet.id
    targetResourceId: funcModule!.outputs.id
    groupId: 'sites'
    privateDnsZoneId: privateEndpoints.dnsZones.sites!
  }
}

@description('Web App resource ID, empty when not deployed.')
output webResourceId string = hasWeb ? webModule!.outputs.id : ''

@description('API App resource ID, empty when not deployed.')
output apiResourceId string = hasApi ? apiModule!.outputs.id : ''

@description('SQL Server resource ID, empty when not deployed.')
output sqlResourceId string = hasSql ? sqlModule!.outputs.id : ''

@description('Function App resource ID, empty when not deployed.')
output funcResourceId string = hasFunc ? funcModule!.outputs.id : ''
