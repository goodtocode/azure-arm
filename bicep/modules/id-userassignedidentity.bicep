@description('Workload-owned user-assigned managed identity name.')
@minLength(3)
@maxLength(128)
param name string

@description('Identity region.')
param location string

@description('Resource tags.')
param tags object = {}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}

@description('Identity resource ID for attachment to an Azure resource.')
output id string = identity.id

@description('Identity object ID for Azure RBAC role assignments.')
output principalId string = identity.properties.principalId

@description('Identity application/client ID for SqlClient identity selection and service-principal SQL SID.')
output clientId string = identity.properties.clientId
