param location string = resourceGroup().location

param logAnalyticsWorkspaceName string ='logAnalyticsWorkspaceName'

param logAnalyticsSku string = 'PerGB2018'

param tags string = 'tags'

param applicationInsightsName string = 'applicationInsightsName'

param Application_Type string = 'web'

param Flow_Type string = 'Bluefield'

param keyVaultName string = 'keyVaultName'

param skuName string = 'standard'

param tenantId string = subscription().tenantId

param storageName string = 'storageName'

param storageSkuName string = 'Standard_LRS'

module loganalystics 'LogAnalyticsworkspace.bicep'= {
  name:'logAnalyticsWorkspace' 
  params:{
    location:location
    logAnalyticsSku: logAnalyticsSku
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
    
  }
}

module appinsights 'app-insight.bicep' = {
  name: 'applicationInsightsName'
  params:{
    location: location
    tags: tags
    applicationInsightsName: applicationInsightsName
    Application_Type: Application_Type
    Flow_Type: Flow_Type

  }
}

module keyvault 'key-vault.bicep'= {
   name:'keyVaultName'
   params:{
    location: location
    keyVaultName: keyVaultName
    skuName: skuName
    tenantId: tenantId

   }
}

module storageaccount 'storage-account.bicep' = {
  name:'storagename'
  params:{
    location: location
    storageName: storageName
    storageSkuName: storageSkuName
  }
}

