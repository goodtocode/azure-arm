param name string
param location string
param sku string = 'Free'
param repositoryUrl string
param branch string

@secure()
param repositoryToken string
param appLocation string
param apiLocation string
param appArtifactLocation string

resource name_resource 'Microsoft.Web/staticSites@2021-01-01' = {
  name: name
  location: location
  tags: {}
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
