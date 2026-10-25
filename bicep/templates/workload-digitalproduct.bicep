// =============================================================================
// workload-digitalproduct
// Archetype : Digital product (web, API, SQL, Function App in any combination)
// Modes     : standalone | shared | network   (see README "Modes")
//   standalone - plan, Log Analytics and App Insights are created in this RG.
//   shared     - plan and App Insights already exist in a shared RG (same subscription).
//   network    - shared + regional VNet integration into an existing subnet.
// Zero trust (private endpoints) lives in workload-digitalproduct-zerotrust.
// Components: a component is deployed when its object parameter is supplied.
// Variables : bicep/variables/workload-digitalproduct-<mode>-<env>.bicepparam
// =============================================================================
targetScope = 'resourceGroup'

import { workloadMode, workloadRegion, sharedRef, vnetRef } from '../types/workload-types.bicep'
import { hostingConfig, webConfig, apiConfig, sqlConfig, funcConfig } from '../types/digitalproduct-types.bicep'

@description('Deployment mode. standalone, shared, or network.')
param mode workloadMode

@description('Azure region for all resources in this deployment.')
param location workloadRegion

@description('Resource tags applied to every resource.')
param tags object

@minLength(1)
@maxLength(40)
@description('Application environment name passed to the apps (for example Development, Production).')
param environmentApp string

@description('Plan and Application Insights names, plus the standalone-only settings used to create them.')
param hosting hostingConfig

@description('Shared RG holding the plan and Application Insights. Required when mode is shared or network.')
param shared sharedRef?

@description('Existing subnet for VNet integration. Required when mode is network.')
param vnet vnetRef?

@description('Web App. Omit to skip.')
param web webConfig?

@description('API App. Omit to skip.')
param api apiConfig?

@description('SQL Server and Database. Omit to skip.')
param sql sqlConfig?

@description('Function App and its storage account. Omit to skip.')
param func funcConfig?

var isStandalone = mode == 'standalone'
var isNetwork = mode == 'network'
var hasWeb = web != null
var hasApi = api != null
var hasSql = sql != null
var hasFunc = func != null
var sharedSubscriptionId = shared.?subscriptionId ?? subscription().subscriptionId
var sharedResourceGroupName = shared.?resourceGroupName ?? resourceGroup().name
var vnetSubscriptionId = vnet.?subscriptionId ?? subscription().subscriptionId

module workModule '../modules/work-loganalyticsworkspace.bicep' = if (isStandalone) {
  name: 'digitalproduct-work'
  params: {
    name: hosting.?workspaceName ?? '${hosting.appiName}-work'
    location: location
    tags: tags
  }
}

module appiModule '../modules/appi-applicationinsights.bicep' = if (isStandalone) {
  name: 'digitalproduct-appi'
  params: {
    name: hosting.appiName
    location: location
    tags: tags
    workResourceId: workModule!.outputs.id
  }
}

module planModule '../modules/plan-appserviceplan.bicep' = if (isStandalone) {
  name: 'digitalproduct-plan'
  params: {
    name: hosting.planName
    location: location
    tags: tags
    sku: hosting.?planSku ?? 'F1'
  }
}

resource appiShared 'Microsoft.Insights/components@2020-02-02' existing = if (!isStandalone) {
  name: hosting.appiName
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

resource planShared 'Microsoft.Web/serverfarms@2023-01-01' existing = if (!isStandalone) {
  name: hosting.planName
  scope: resourceGroup(sharedSubscriptionId, sharedResourceGroupName)
}

resource subnetExisting 'Microsoft.Network/virtualNetworks/subnets@2023-06-01' existing = if (isNetwork) {
  name: '${vnet!.vnetName}/${vnet!.subnetName}'
  scope: resourceGroup(vnetSubscriptionId, vnet!.resourceGroupName)
}

var appiKey = isStandalone ? appiModule!.outputs.InstrumentationKey : appiShared!.properties.InstrumentationKey
var appiConnection = isStandalone ? appiModule!.outputs.Connectionstring : appiShared!.properties.ConnectionString
var planId = isStandalone ? planModule!.outputs.id : planShared!.id
var subnetId = isNetwork ? subnetExisting!.id : ''
var routeAllEnabled = vnet.?routeAllEnabled ?? false
var imagePullEnabled = vnet.?imagePullEnabled ?? false
var contentShareEnabled = vnet.?contentShareEnabled ?? false
var backupRestoreEnabled = vnet.?backupRestoreEnabled ?? false

module apiModule '../modules/api-appservice.bicep' = if (hasApi) {
  name: 'digitalproduct-api'
  params: {
    name: api!.name
    location: location
    tags: tags
    environment: environmentApp
    appiKey: appiKey
    appiConnection: appiConnection
    planId: planId
    subnetId: subnetId
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: contentShareEnabled
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
}

module webModule '../modules/web-appservice.bicep' = if (hasWeb) {
  name: 'digitalproduct-web'
  params: {
    name: web!.name
    location: location
    tags: tags
    environment: environmentApp
    appiKey: appiKey
    appiConnection: appiConnection
    planId: planId
    subnetId: subnetId
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: contentShareEnabled
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
}

module sqlModule '../modules/sql-sqlserverdatabase.bicep' = if (hasSql) {
  name: 'digitalproduct-sql'
  params: {
    name: sql!.serverName
    location: location
    tags: tags
    adminLogin: sql!.adminLogin
    adminPassword: sql!.adminPassword
    sqldbName: sql!.databaseName
    sku: sql.?databaseSku ?? 'Basic'
  }
}

// Network mode restricts the Function App storage to the integration subnet.
module storageModule '../modules/st-storageaccount.bicep' = if (hasFunc) {
  name: 'digitalproduct-st'
  params: {
    name: func!.storageName
    location: location
    tags: tags
    sku: func.?storageSku ?? 'Standard_LRS'
    networkDefaultAction: isNetwork ? 'Deny' : 'Allow'
    allowedVirtualNetworkResourceIds: isNetwork ? [subnetId] : []
  }
}

module funcModule '../modules/func-functionsapp.bicep' = if (hasFunc) {
  name: 'digitalproduct-func'
  params: {
    name: func!.name
    location: location
    tags: tags
    environmentApp: environmentApp
    appiKey: appiKey
    appiConnection: appiConnection
    planId: planId
    stName: func!.storageName
    funcRuntime: func.?runtime ?? 'dotnet-isolated'
    funcVersion: func.?version ?? 4
    alwaysOn: func.?alwaysOn ?? false
    subnetId: subnetId
    vnetRouteAllEnabled: routeAllEnabled
    vnetImagePullEnabled: imagePullEnabled
    vnetContentShareEnabled: contentShareEnabled
    vnetBackupRestoreEnabled: backupRestoreEnabled
  }
  dependsOn: [storageModule]
}

@description('Deployment mode that was applied.')
output mode string = mode

@description('Web App resource ID, empty when not deployed.')
output webResourceId string = hasWeb ? webModule!.outputs.id : ''

@description('API App resource ID, empty when not deployed.')
output apiResourceId string = hasApi ? apiModule!.outputs.id : ''

@description('SQL Server resource ID, empty when not deployed.')
output sqlResourceId string = hasSql ? sqlModule!.outputs.id : ''
