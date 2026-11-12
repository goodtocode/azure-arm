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
    kind: 'SqlAuth'
    administratorLogin: 'prototype-admin'
  }
}
