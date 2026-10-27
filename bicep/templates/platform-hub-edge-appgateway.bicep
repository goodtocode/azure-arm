targetScope = 'resourceGroup'

// Common
param location string = resourceGroup().location
param tags object

// Hub network (existing, deployed by platform-hub-network-*)
@minLength(1)
@maxLength(90)
@description('Specifies the resource group of the existing hub virtual network. 1-90 characters.')
param hubNetworkResourceGroupName string

@minLength(2)
@maxLength(64)
@description('Specifies the name of the existing hub virtual network. 2-64 characters, letters, numbers, and -')
param vnetName string

@minLength(1)
@maxLength(80)
@description('Specifies the name of the Application Gateway subnet. 1-80 characters.')
param snetNameAppGateway string

@minLength(9)
@maxLength(18)
@description('Specifies the address prefix for the Application Gateway subnet. Example: 10.0.3.0/24')
param snetCidrAppGateway string

@minLength(9)
@maxLength(18)
@description('Specifies the address prefix for AzureFirewallSubnet. Minimum /26. Example: 10.0.4.0/26')
param snetCidrAzureFirewall string

// Application Gateway
@minLength(1)
@maxLength(76)
@description('Specifies the name of the Application Gateway. 1-76 characters.')
param agwName string

@minValue(0)
@maxValue(125)
@description('Specifies the minimum autoscale instance count.')
param agwMinCapacity int = 1

@minValue(1)
@maxValue(125)
@description('Specifies the maximum autoscale instance count.')
param agwMaxCapacity int = 2

@description('Specifies the WAF mode. Prevention blocks matching requests; Detection only logs them.')
@allowed([
  'Prevention'
  'Detection'
])
param wafMode string = 'Prevention'

@description('Specifies the products served through the gateway. The gateway is deployed only when at least one is given.')
param backends backendType[] = []

type backendType = {
  @minLength(2)
  @maxLength(80)
  @description('Name shared by the listener, pool, settings, probe and rule.')
  name: string

  @minLength(1)
  @maxLength(253)
  @description('Host name the listener matches, e.g. app.example.com.')
  hostName: string

  @minLength(1)
  @maxLength(253)
  @description('Backend FQDN, e.g. the App Service default host name. Reached over HTTPS.')
  backendFqdn: string
}

// Firewall
@minLength(1)
@maxLength(49)
@description('Specifies the name of the Azure Firewall. 1-49 characters.')
param firewallName string

@description('Specifies the Azure Firewall tier.')
@allowed([
  'Standard'
  'Premium'
])
param firewallTier string = 'Standard'

@description('Specifies the firewall policy threat intelligence mode.')
@allowed([
  'Off'
  'Alert'
  'Deny'
])
param firewallThreatIntelMode string = 'Alert'

// DDoS
@description('Enables Azure DDoS IP Protection on the gateway and firewall public IPs.')
param ddosIpProtection bool = false

var wafPolicyName = '${agwName}-waf'

var agwSecurityRules = [
  {
    name: 'AllowGatewayManager'
    priority: 100
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '65200-65535'
    sourceAddressPrefix: 'GatewayManager'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowAzureLoadBalancer'
    priority: 110
    direction: 'Inbound'
    access: 'Allow'
    protocol: '*'
    sourcePortRange: '*'
    destinationPortRange: '*'
    sourceAddressPrefix: 'AzureLoadBalancer'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowHttpInternet'
    priority: 120
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '80'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
  }
  {
    name: 'AllowHttpsInternet'
    priority: 130
    direction: 'Inbound'
    access: 'Allow'
    protocol: 'Tcp'
    sourcePortRange: '*'
    destinationPortRange: '443'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: '*'
  }
]

//
// Subnets live in the hub network resource group
//
module nsgAgw '../modules/nsg-networksecuritygroup.bicep' = {
  name: 'nsgNameAppGateway'
  scope: resourceGroup(hubNetworkResourceGroupName)
  params: {
    name: '${snetNameAppGateway}-nsg'
    tags: tags
    securityRules: agwSecurityRules
  }
}

module snetAgw '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetNameAppGateway'
  scope: resourceGroup(hubNetworkResourceGroupName)
  params: {
    vnetName: vnetName
    snetName: snetNameAppGateway
    cidr: snetCidrAppGateway
    nsgId: nsgAgw.outputs.id
  }
}

module snetFirewall '../modules/snet-virtualnetworksubnet.bicep' = {
  name: 'snetNameAzureFirewall'
  scope: resourceGroup(hubNetworkResourceGroupName)
  dependsOn: [
    snetAgw
  ]
  params: {
    vnetName: vnetName
    snetName: 'AzureFirewallSubnet'
    cidr: snetCidrAzureFirewall
  }
}

//
// Edge resources
//
module pipAgw '../modules/pip-publicipaddress.bicep' = {
  name: 'pipNameAppGateway'
  params: {
    name: '${agwName}-pip'
    location: location
    tags: tags
    ddosProtection: ddosIpProtection
  }
}

module pipFirewall '../modules/pip-publicipaddress.bicep' = {
  name: 'pipNameFirewall'
  params: {
    name: '${firewallName}-pip'
    location: location
    tags: tags
    ddosProtection: ddosIpProtection
  }
}

module waf '../modules/agwwaf-applicationgatewaywafpolicy.bicep' = {
  name: 'wafPolicyName'
  params: {
    name: wafPolicyName
    location: location
    tags: tags
    mode: wafMode
  }
}

module agw '../modules/agw-applicationgateway.bicep' = if (!empty(backends)) {
  name: 'agwName'
  params: {
    name: agwName
    location: location
    tags: tags
    subnetId: snetAgw.outputs.id
    publicIpId: pipAgw.outputs.id
    wafPolicyId: waf.outputs.id
    minCapacity: agwMinCapacity
    maxCapacity: agwMaxCapacity
    backends: backends
  }
}

module firewall '../modules/fw-azurefirewall.bicep' = {
  name: 'firewallName'
  params: {
    name: firewallName
    location: location
    tags: tags
    subnetId: snetFirewall.outputs.id
    publicIpId: pipFirewall.outputs.id
    tier: firewallTier
    threatIntelMode: firewallThreatIntelMode
  }
}

@description('Resource ID of the Application Gateway. Empty when no backends are configured.')
output applicationGatewayId string = !empty(backends) ? agw!.outputs.id : ''

@description('Private IP of the Azure Firewall, the next hop for spoke route tables.')
output firewallPrivateIp string = firewall.outputs.privateIp

@description('Resource ID of the firewall policy. Add rule collection groups to it.')
output firewallPolicyId string = firewall.outputs.policyId
