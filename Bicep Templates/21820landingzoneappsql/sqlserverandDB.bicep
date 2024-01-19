@description('Location for all resources.')
param location string = resourceGroup().location

@description('The name of the SQL logical server.')
param serverName string = 'serverName'

@description('The name of the SQL Database.')
param sqlDBName string = 'SampleDB'

@description('The administrator username of the SQL logical server.')
param administratorLogin string = 'administratorLogin'

@description('The administrator password of the SQL logical server.')
@secure()
param administratorLoginPassword string = ''

param tags string = 'tags'

param collation string = 'collation'

param maxSizeBytes int = 123

resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: serverName
  location: location
  tags:{
    '${tags}': tags
  }
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: administratorLoginPassword
  }
}

resource sqlDB 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDBName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties:{
    collation: collation
    maxSizeBytes: maxSizeBytes
    
  }
}




