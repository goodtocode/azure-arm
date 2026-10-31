using '../templates/workload-usermachines.bicep'

// Mode 3 - Network: machines join an existing spoke subnet. No public IP.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-usermachines.bicep -p bicep/variables/workload-usermachines-network-dev.bicepparam

var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'

param mode = 'network'
param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param subnet = {
  resourceGroupName: 'network-${environmentIac}-${regionIac}-${instanceIac}-rg'
  vnetName: 'network-${environmentIac}-${regionIac}-${instanceIac}-vnet'
  subnetName: 'network-${environmentIac}-${regionIac}-${instanceIac}-machines-snet'
}

param machines = [
  {
    name: '${productIac}-${environmentIac}-vm01'
    computerName: 'dev01'
    size: 'Standard_D2s_v5'
    os: 'Windows11'
  }
]

param adminUsername = 'azureadmin'
param adminPassword = readEnvironmentVariable('VM_ADMIN_PASSWORD', 'PASS_FROM_CLI_PARAMETERS')
