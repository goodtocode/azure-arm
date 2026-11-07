using '../../templates/workload-digitalproduct.bicep'

param mode = 'standalone'
param location = 'westus2'
param environmentApp = 'Development'
param tags = {}
param hosting = {
  appiName: 'contract-test-appi'
  planName: 'contract-test-asp'
  workspaceName: 'contract-test-log'
}
param sql = {
  serverName: 'contract-test-sql'
  databaseName: 'contract-test'
  server: {
    kind: 'EntraOnly'
    adminPassword: '<SQL_ADMIN_PASSWORD>'
    administrator: {
      login: 'SQL Administrators'
      objectId: '11111111-1111-1111-1111-111111111111'
      tenantId: '22222222-2222-2222-2222-222222222222'
    }
  }
}
