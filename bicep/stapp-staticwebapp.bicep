//https://www.aaron-powell.com/posts/2022-06-29-deploy-swa-with-bicep/
@description('Name of the Static Web App. (stapp)')
param name string

@description('Azure region of the deployment')
param location string = resourceGroup().location

@allowed([ 'Free', 'Standard' ])
param sku string = 'Free'

@description('Tags to add to the resources')
param tags object = {}

@secure()
param repositoryToken string
param appLocation string
param apiLocation string
param appArtifactLocation string

resource name_resource 'Microsoft.Web/staticSites@2022-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    repositoryUrl: repositoryUrl
    branch: branch
    repositoryToken: repositoryToken
    buildProperties: {
      appLocation: appLocation
      apiLocation: apiLocation
      appArtifactLocation: appArtifactLocation
    }
  }
  sku: {
    tier: sku
    name: sku
  }
}
