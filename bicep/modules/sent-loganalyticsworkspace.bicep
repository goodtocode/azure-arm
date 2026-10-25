
@description('The name of the Log Analytics workspace. Must be 4-63 characters, using only letters, numbers, and hyphens.')
@minLength(4)
@maxLength(63)
param name string

@description('The Azure region where the Log Analytics workspace will be deployed.')
param location string

@description('The SKU (pricing tier) for the Log Analytics workspace. Allowed values: Free, PerGB2018, CapacityReservation. Default is PerGB2018.')
@allowed([
  'Free'
  'PerGB2018'
  'CapacityReservation'
])
param sku string = 'PerGB2018'

@description('Tags to apply to the Log Analytics workspace resource.')
param tags object = {}

@description('The data retention period in days. Minimum is 30. Default is 30.')
@minValue(30)
param retentionInDays int = 30

// Sentinel = the plain workspace (work-) plus onboarding
module workspace 'work-loganalyticsworkspace.bicep' = {
  name: 'sent-${name}'
  params: {
    name: name
    location: location
    sku: sku
    tags: tags
    retentionInDays: retentionInDays
  }
}

resource workResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: name
  dependsOn: [
    workspace
  ]
}

resource onboarding 'Microsoft.SecurityInsights/onboardingStates@2021-03-01-preview' = {
  name: 'default'
  scope: workResource
  properties: {}
}

@description('Resource ID of the Log Analytics workspace.')
output id string = workspace.outputs.id

@description('Resource ID of the Sentinel onboarding state.')
output onboardingId string = onboarding.id
