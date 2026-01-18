param name string
param location string
@allowed([
  'Free'
  'PerGB2018'
  'CapacityReservation'
])
param sku string
param tags object = {}
param retentionInDays int = 30
param customerManagedKey bool = false

resource workResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  properties: {
    sku: {
      name: sku
    }
    retentionInDays: retentionInDays
  }
}


resource onboarding 'Microsoft.OperationalInsights/workspaces/providers/onboardingStates@2021-03-01-preview' = {
  name: '${workResource.name}/Microsoft.SecurityInsights/default'
  properties: {}
  dependsOn: [ workResource ]
}

output id string  = workResource.id
output onboardingId string = onboarding.id
