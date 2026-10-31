
targetScope = 'resourceGroup'

param tenantId string = tenant().tenantId
param location string = resourceGroup().location
param tags object

@maxLength(64)
@description('Subscription ID of the shared workspace. Used only when hubMgmtResourceGroupName is set.')
param hubMgmtSubscriptionId string = subscription().subscriptionId

@maxLength(90)
@description('Resource group of an existing shared Log Analytics workspace. Leave empty to create the workspace in this resource group.')
param hubMgmtResourceGroupName string = ''

@minLength(4)
@maxLength(63)
@description('Specifies the name of the Log Analytics workspace, created here or existing in the hub resource group. 4-63 characters, letters, numbers, and -')
param workName string

@minLength(1)
@maxLength(255)
@description('Specifies the name of the Application Insights resource. 1-255 characters, letters, numbers, and -')
param appiName string

@minLength(5)
@maxLength(50)
@description('Specifies the name of the App Configuration store. 5-50 characters, only lowercase letters, numbers, and -')
param appcsName string
@minLength(4)
@maxLength(8)
@description('Specifies the SKU for the App Configuration store. Allowed values: free, standard.')
@allowed([
  'free'
  'standard'
])
param appcsSku string = 'free'

// App Service Plan parameters
@minLength(2)
@maxLength(2)
@description('Specifies the SKU for the App Service Plan. Allowed values: F1, D1, B1, B2, B3, S1, S2, S3, P1, P2, P3, P4, Y1.')
@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
  'Y1'
])
param planSku string = 'F1'
@minLength(1)
@maxLength(40)
@description('Specifies the name of the App Service Plan. 1-40 characters, letters, numbers, and -')
param planName string

@minLength(7)
@maxLength(8)
@description('Specifies the SKU for the Key Vault. Allowed values: standard, premium.')
@allowed([
  'standard'
  'premium'
])
param kvSku string = 'standard'

@minLength(0)
@maxLength(24)
@description('Specifies the Key Vault name. Defaults to a value derived from appcsName when not provided.')
param kvName string = ''

@description('Subnet resource IDs allowed to access spoke Key Vault. Supply the spoke management subnet for private access.')
param kvAllowedVirtualNetworkResourceIds array = []

@description('public = Application Insights and App Configuration accept public traffic and keys (basic hub-and-spoke with public endpoints). restricted = ingestion, query and App Configuration public access disabled.')
@allowed([
  'public'
  'restricted'
])
param networkAccess string = 'restricted'

var restricted = networkAccess == 'restricted'

// '-appcs-kv' is 9 chars, so truncate base to 15 chars max for 24-char total
var kvNameBase = toLower(replace(appcsName, '-', ''))
var kvNameTrunc = substring(kvNameBase, 0, min(15, length(kvNameBase)))
var kvNameDefault = '${kvNameTrunc}-appcs-kv'
var kvNameResolved = empty(kvName) ? kvNameDefault : kvName

var useSharedWorkspace = !empty(hubMgmtResourceGroupName)

module lawModule '../modules/law-loganalyticsworkspace.bicep' = if (!useSharedWorkspace) {
  name: 'workName'
  params: {
    name: workName
    location: location
    tags: tags
  }
}

var workResourceId = useSharedWorkspace ? resourceId(hubMgmtSubscriptionId, hubMgmtResourceGroupName, 'Microsoft.OperationalInsights/workspaces', workName) : lawModule!.outputs.id

module appiModule '../modules/appi-applicationinsights.bicep' = {
  name: 'appiName'
  params:{
    location: location
    tags: tags
    name: appiName
    workResourceId: workResourceId
    publicNetworkAccessForIngestion: restricted ? 'Disabled' : 'Enabled'
    publicNetworkAccessForQuery: restricted ? 'Disabled' : 'Enabled'
  }
}

module kvModule '../modules/kv-keyvault.bicep' = {
  name: 'kvName'
  params: {
    location: location
    tags: tags
    name: kvNameResolved
    sku: kvSku
    tenantId: tenantId
    publicNetworkAccess: empty(kvAllowedVirtualNetworkResourceIds) ? 'Enabled' : 'Disabled'
    networkDefaultAction: empty(kvAllowedVirtualNetworkResourceIds) ? 'Allow' : 'Deny'
    allowedVirtualNetworkResourceIds: kvAllowedVirtualNetworkResourceIds
  }
} 

module appcsModule '../modules/appcs-appconfigurationstore.bicep' = {
  name: 'appcsName'
  params: {
    name: appcsName
    sku: appcsSku
    location: location
    publicNetworkAccess: restricted ? 'Disabled' : 'Enabled'
    disableLocalAuth: restricted
  }
}

module planModule '../modules/plan-appserviceplan.bicep' = {
  name: 'planModule'
  params: {
    name: planName
    sku: planSku
    location: location
  }
}
