param location string = resourceGroup().location

param logAnalyticsWorkspaceName string ='logAnalyticsWorkspace'

param logAnalyticsSku string = 'PerGB2018'

param tags string = 'tags'

param applicationInsightsName string = 'applicationInsightsName'

param Application_Type string = 'web'

param Flow_Type string = 'Bluefield'

param keyVaultName string = 'keyVaultName'

param skuName string = 'standard'

param tenantId string = subscription().tenantId

param storageName string = 'storagename'

param storageSkuName string = 'Standard_LRS'

param sku string = 'F1'

param appServicePlanName string = 'appServicePlanName'

param appName string = 'appName'

param appiKey string = 'appiKey'

param appiConnection string = 'appiConnection'

param rgEnvironment string = 'Development'

module loganalystics 'LogAnalyticsworkspace.bicep'= {
  name:'logAnalyticsWorkspace' 
  scope:resourceGroup('Subscriptionid','shared resourcegrpname')
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

module appserviceplan 'app-serviceplan.bicep' = {
  name:'appServicePlanName'
  scope:resourceGroup('Subscriptionid','shared resourcegrpname')
  params:{
    location: location
    sku: sku
    appServicePlanName: appServicePlanName
  }  
}

module appservice 'app-service.bicep' = {
  name: 'appname'
  params:{
    location: location
    appName: appName
    appiKey: appiKey
    appiConnection: appiConnection
    rgEnvironment: rgEnvironment
  }
}
  



