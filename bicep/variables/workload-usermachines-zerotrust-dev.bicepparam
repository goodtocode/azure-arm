using '../templates/workload-usermachines-zerotrust.bicep'

// Mode 4 - Zero trust: no public IP, Trusted Launch, encryption at host, Entra ID login. Reach via Bastion.
// Deploy: az deployment group create -g <rg> -f bicep/templates/workload-usermachines-zerotrust.bicep -p bicep/variables/workload-usermachines-zerotrust-dev.bicepparam

var scopeOwner = 'ScopeOrTenant'
var productIac = 'PRODUCT'
var environmentIac = 'dev'
var regionIac = 'wus2'
var instanceIac = '001'

param location = 'westus2'
param tags = { Environment: environmentIac, CostCenter: '0000' }

param subnet = {
  resourceGroupName: '${scopeOwner}-spoke-network-${environmentIac}-${regionIac}-${instanceIac}-rg'
  vnetName: 'spoke-network-${environmentIac}-${regionIac}-${instanceIac}-vnet'
  subnetName: 'spoke-network-${environmentIac}-${regionIac}-${instanceIac}-machines-snet'
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
