<#
.SYNOPSIS
Deploys one platform spoke: the network and management resource groups, and optionally AI, in the spoke subscription.

.DESCRIPTION
Runs what-if, then deploys platform-spoke-network-publicroute and platform-shared-mgmt (pointed at the hub workspace), and with -IncludeAi platform-shared-ai-foundry. Resource group names follow {product}-{env}-{region}-{instance}-rg, with region and instance read from the spoke network parameter file for the environment.
The hub management resource group is read from the hub network parameter file, so deploy the hub first.
The GitHub workflow platform-spoke-iac.yml does the same thing; use this script for a manual bootstrap.

.EXAMPLE
# What-if only for dev (single line, safe to paste):
pwsh -File ./hub-and-spoke/New-PlatformSpoke.ps1 -SpokeSubscriptionId "<spoke-subscription-id>" -HubSubscriptionId "<hub-subscription-id>" -Environment dev -WhatIfOnly

.EXAMPLE
# Deploy prod including AI (single line, safe to paste):
pwsh -File ./hub-and-spoke/New-PlatformSpoke.ps1 -SpokeSubscriptionId "<spoke-subscription-id>" -HubSubscriptionId "<hub-subscription-id>" -Environment prod -IncludeAi -AiLocation "westus"

.NOTES
- Requires the Azure CLI. -IncludeAi needs platform-shared-ai-foundry-{env}.bicepparam; AI models are only offered in some regions, hence -AiLocation.
- Finds templates and variables under bicep/ (template repo) or .azure/ (consumer repos); run it from any folder.
#>
param(
    [Parameter(Mandatory)][string]$SpokeSubscriptionId,
    [Parameter(Mandatory)][string]$HubSubscriptionId,
    [ValidateSet('dev', 'prod')][string]$Environment = 'dev',
    [string]$Location = 'westus2',
    [string]$AiLocation = '',
    [switch]$IncludeAi,
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\lib\Platform.Common.ps1"

if (-not $AiLocation) { $AiLocation = $Location }
$root = Get-BicepRoot
$hubNetworkParams = Join-Path $root 'variables\platform-hub-network-publicroute-plat.bicepparam'
$spokeNetworkParams = Join-Path $root "variables\platform-spoke-network-publicroute-$Environment.bicepparam"
$hubRegion = Get-BicepParamValue -File $hubNetworkParams -Name 'regionIac'
$hubInstance = Get-BicepParamValue -File $hubNetworkParams -Name 'instanceIac'
$region = Get-BicepParamValue -File $spokeNetworkParams -Name 'regionIac'
$instance = Get-BicepParamValue -File $spokeNetworkParams -Name 'instanceIac'
$hubMgmtRg = "mgmt-plat-$hubRegion-$hubInstance-rg"

az login | Out-Null
az account set --subscription $SpokeSubscriptionId

Invoke-PlatformDeployment -WhatIfOnly:$WhatIfOnly -Location $Location `
    -ResourceGroup "network-$Environment-$region-$instance-rg" `
    -Template (Join-Path $root 'templates\platform-spoke-network-publicroute.bicep') `
    -Parameters $spokeNetworkParams

Invoke-PlatformDeployment -WhatIfOnly:$WhatIfOnly -Location $Location `
    -ResourceGroup "mgmt-$Environment-$region-$instance-rg" `
    -Template (Join-Path $root 'templates\platform-shared-mgmt.bicep') `
    -Parameters (Join-Path $root "variables\platform-shared-mgmt-$Environment.bicepparam") `
    -ExtraParameters @('--parameters', "hubMgmtSubscriptionId=$HubSubscriptionId", "hubMgmtResourceGroupName=$hubMgmtRg")

if ($IncludeAi) {
    $aiParams = Join-Path $root "variables\platform-shared-ai-foundry-$Environment.bicepparam"
    Invoke-PlatformDeployment -WhatIfOnly:$WhatIfOnly -Location $AiLocation `
        -ResourceGroup "ai-$Environment-$region-$instance-rg" `
        -Template (Join-Path $root 'templates\platform-shared-ai-foundry.bicep') `
        -Parameters $aiParams
}
