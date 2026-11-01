<#
.SYNOPSIS
Peers a spoke VNet with the hub VNet in both directions.

.DESCRIPTION
Run it after the hub and spoke networks exist. VNet and resource group names follow {product}-{env}-{region}-{instance}-{type}, with region and instance read from the hub and spoke network parameter files.

.EXAMPLE
# Peer the dev spoke (single line, safe to paste):
pwsh -File ./hub-and-spoke/New-VnetPeering.ps1 -HubSubscriptionId "<hub-subscription-id>" -SpokeSubscriptionId "<spoke-subscription-id>" -Environment dev

.NOTES
- Requires the Azure CLI and network permissions in both subscriptions.
- Finds the peering module under bicep/ (template repo) or .azure/ (consumer repos); run it from any folder.
#>
param(
    [Parameter(Mandatory)][string]$HubSubscriptionId,
    [Parameter(Mandatory)][string]$SpokeSubscriptionId,
    [ValidateSet('dev', 'prod')][string]$Environment = 'dev'
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\lib\Platform.Common.ps1"

$root = Get-BicepRoot
$peeringModule = Join-Path $root 'modules\vnetpeer-virtualnetworkpeering.bicep'
$hubParams = Join-Path $root 'variables\platform-hub-network-publicroute-plat.bicepparam'
$spokeParams = Join-Path $root "variables\platform-spoke-network-publicroute-$Environment.bicepparam"
$hubSlots = "$(Get-BicepParamValue $hubParams 'regionIac')-$(Get-BicepParamValue $hubParams 'instanceIac')"
$spokeSlots = "$(Get-BicepParamValue $spokeParams 'regionIac')-$(Get-BicepParamValue $spokeParams 'instanceIac')"

$hubRg = "network-plat-$hubSlots-rg"
$hubVnet = "network-plat-$hubSlots-vnet"
$spokeRg = "network-$Environment-$spokeSlots-rg"
$spokeVnet = "network-$Environment-$spokeSlots-vnet"
$hubVnetId = "/subscriptions/$HubSubscriptionId/resourceGroups/$hubRg/providers/Microsoft.Network/virtualNetworks/$hubVnet"
$spokeVnetId = "/subscriptions/$SpokeSubscriptionId/resourceGroups/$spokeRg/providers/Microsoft.Network/virtualNetworks/$spokeVnet"

az login | Out-Null

az deployment group create --subscription $SpokeSubscriptionId --resource-group $spokeRg `
    --template-file $peeringModule `
    --parameters localVnetName=$spokeVnet peeringName=spoke-to-hub remoteVnetId=$hubVnetId
if ($LASTEXITCODE -ne 0) { throw "Spoke-to-hub peering failed." }

az deployment group create --subscription $HubSubscriptionId --resource-group $hubRg `
    --template-file $peeringModule `
    --parameters localVnetName=$hubVnet peeringName="hub-to-$spokeVnet" remoteVnetId=$spokeVnetId
if ($LASTEXITCODE -ne 0) { throw "Hub-to-spoke peering failed." }
