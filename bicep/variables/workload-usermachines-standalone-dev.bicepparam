using '../templates/workload-usermachines.bicep'

// Mode 1 - Standalone: own VNet, subnet and NSG in the home RG. No shared resources.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-usermachines.bicep -p bicep/variables/workload-usermachines-standalone-dev.bicepparam

var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'
var prefix = '${productIac}-${environmentIac}-${regionIac}-${instanceIac}'

param mode = 'standalone'
param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param ownNetwork = {
  vnetName: '${prefix}-vnet'
  vnetCidr: '10.50.0.0/16'
  subnetName: '${prefix}-machines-snet'
  subnetCidr: '10.50.1.0/24'
  // allowedAdminCidr: '203.0.113.10/32'
}

param machines = [
  {
    name: '${productIac}-${environmentIac}-vm01'
    computerName: 'dev01'
    size: 'Standard_D2s_v5'
    os: 'Windows11'
    // publicIp: true
  }
]

param adminUsername = 'azureadmin'
param adminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD', 'PASS_FROM_CLI_PARAMETERS')
