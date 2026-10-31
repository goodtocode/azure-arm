<#
.SYNOPSIS
Deploys the platform hub: the management and network resource groups in the hub subscription.

.DESCRIPTION
Runs what-if, then deploys platform-hub-mgmt and platform-hub-network-publicroute. Resource group names follow {product}-{env}-{region}-{instance}-rg, with region and instance read from the hub network parameter file so they always match the templates.
The GitHub workflow platform-hub-iac.yml does the same thing; use this script for a manual bootstrap.

.EXAMPLE
# What-if only (single line, safe to paste):
pwsh -File ./hub-and-spoke/New-PlatformHub.ps1 -HubSubscriptionId "<hub-subscription-id>" -WhatIfOnly

.EXAMPLE
# Deploy (single line, safe to paste):
pwsh -File ./hub-and-spoke/New-PlatformHub.ps1 -HubSubscriptionId "<hub-subscription-id>" -Location "westus2"

.NOTES
- Requires the Azure CLI and permission to register providers and deploy in the hub subscription.
- Finds templates and variables under bicep/ (template repo) or .azure/ (consumer repos); run it from any folder.
#>
param(
    [Parameter(Mandatory)][string]$HubSubscriptionId,
    [string]$Location = 'westus2',
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\lib\Platform.Common.ps1"

$root = Get-BicepRoot
$networkParams = Join-Path $root 'variables\platform-hub-network-publicroute-plat.bicepparam'
$region = Get-BicepParamValue -File $networkParams -Name 'regionIac'
$instance = Get-BicepParamValue -File $networkParams -Name 'instanceIac'

az login | Out-Null
az account set --subscription $HubSubscriptionId

# Sentinel requires registration
az provider register --namespace Microsoft.OperationsManagement
az provider register --namespace Microsoft.SecurityInsights

Invoke-PlatformDeployment -WhatIfOnly:$WhatIfOnly -Location $Location `
    -ResourceGroup "mgmt-plat-$region-$instance-rg" `
    -Template (Join-Path $root 'templates\platform-hub-mgmt.bicep') `
    -Parameters (Join-Path $root 'variables\platform-hub-mgmt-plat.bicepparam')

Invoke-PlatformDeployment -WhatIfOnly:$WhatIfOnly -Location $Location `
    -ResourceGroup "network-plat-$region-$instance-rg" `
    -Template (Join-Path $root 'templates\platform-hub-network-publicroute.bicep') `
    -Parameters $networkParams
