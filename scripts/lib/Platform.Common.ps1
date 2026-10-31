# Shared helpers for the platform deployment scripts. Dot-source it: . "$PSScriptRoot\..\lib\Platform.Common.ps1"

$script:PlatformLibRoot = $PSScriptRoot

# Folder that holds templates/, variables/ and modules/: <repo>/bicep in the template repo, <repo>/.azure in consumer repos.
function Get-BicepRoot {
    param([string]$LibRoot = $script:PlatformLibRoot)
    $root = (Resolve-Path (Join-Path $LibRoot '..\..')).Path
    $bicep = Join-Path $root 'bicep'
    if (Test-Path (Join-Path $bicep 'templates')) { return $bicep }
    return $root
}

# Reads a quoted value such as `var regionIac = 'wus2'` from a .bicepparam file, so resource group names stay in step with the templates.
function Get-BicepParamValue {
    param([Parameter(Mandatory)][string]$File, [Parameter(Mandatory)][string]$Name)
    if (-not (Test-Path $File)) { throw "Parameter file not found: $File" }
    $match = Select-String -Path $File -Pattern "^\s*(?:var|param)\s+$Name\s*=\s*'([^']*)'" | Select-Object -First 1
    if (-not $match) { throw "'$Name' was not found in $File" }
    return $match.Matches[0].Groups[1].Value
}

# Runs what-if, then the deployment unless -WhatIfOnly, for one resource group.
function Invoke-PlatformDeployment {
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$Template,
        [Parameter(Mandatory)][string]$Parameters,
        [string[]]$ExtraParameters = @(),
        [string]$Subscription = '',
        [switch]$WhatIfOnly
    )
    $sub = if ($Subscription) { @('--subscription', $Subscription) } else { @() }
    az group create --name $ResourceGroup --location $Location @sub | Out-Null
    az deployment group what-if --resource-group $ResourceGroup --template-file $Template --parameters $Parameters @ExtraParameters @sub
    if ($LASTEXITCODE -ne 0) { throw "what-if failed for $ResourceGroup" }
    if ($WhatIfOnly) { return }
    az deployment group create --resource-group $ResourceGroup --template-file $Template --parameters $Parameters @ExtraParameters @sub
    if ($LASTEXITCODE -ne 0) { throw "Deployment failed for $ResourceGroup" }
}
