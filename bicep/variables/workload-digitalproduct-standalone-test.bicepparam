using '../templates/workload-digitalproduct.bicep'

// Existing server ownership is independent of standalone hosting. This deployment manages only the new database.
param mode = 'standalone'
param location = 'westus2'
param environmentApp = 'Development'
param tags = { Environment: 'test' }

param hosting = {
  appiName: 'product-test-appi'
  planName: 'product-test-asp'
  planSku: 'B1'
  workspaceName: 'product-test-log'
}

param api = { name: 'product-test-api', userAssignedIdentityName: 'product-test-api-id' }
param sql = {
  serverName: 'shared-test-sql'
  databaseName: 'product-test'
  server: {
    kind: 'Existing'
    resourceGroupName: 'shared-test-rg'
  }
}
