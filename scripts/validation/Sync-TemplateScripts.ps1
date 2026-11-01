<#
.SYNOPSIS
Checks a consumer repo's scripts folder against this template repo, and optionally brings it up to date.

.DESCRIPTION
The template repo is the master for the Entra, dotnet and test scripts (and the hub-and-spoke scripts with -IncludeHubAndSpoke). The target is another repo's scripts folder, for example ../my-product/.azure/scripts.
Reports each managed file as Missing, Different (ignoring line endings) or Extra (present in the target but no longer in the template). Exits 1 when anything differs, unless -Apply is used.
-Apply copies missing and different files (using the target's line endings, CRLF by default) and deletes extra files in the managed folders. Files outside the managed folders, such as validation/, are never touched.

.EXAMPLE
# Check for drift (single line, safe to paste):
pwsh -File ./validation/Sync-TemplateScripts.ps1 -Target "../my-product/.azure/scripts"

.EXAMPLE
# Bring a repo up to date, including hub-and-spoke (single line, safe to paste):
pwsh -File ./validation/Sync-TemplateScripts.ps1 -Target "../my-product/.azure/scripts" -IncludeHubAndSpoke -Apply

.NOTES
- Review the target repo's git diff after -Apply; nothing is committed.
- Run it from any folder; the source is the scripts folder that contains this script.
#>
param(
    [Parameter(Mandatory)][string]$Target,
    [switch]$IncludeHubAndSpoke,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
$source = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path $Target)) { throw "Target folder not found: $Target" }
$target = (Resolve-Path $Target).Path
if ($target -eq $source) { throw "Target and source are the same folder." }

$folders = @('entra', 'dotnet', 'lib', 'tests')
$rootFiles = @('New-EntraDotnetSolution.ps1')
$platformFiles = @('lib\Platform.Common.ps1', 'tests\Platform.Common.Tests.ps1')
if ($IncludeHubAndSpoke) { $folders += 'hub-and-spoke' }

function Get-Managed([string]$Base) {
    $files = @()
    foreach ($f in $rootFiles) { if (Test-Path (Join-Path $Base $f)) { $files += $f } }
    foreach ($d in $folders) {
        $dir = Join-Path $Base $d
        if (Test-Path $dir) {
            $files += Get-ChildItem $dir -Recurse -File | ForEach-Object { $_.FullName.Substring($Base.Length + 1) }
        }
    }
    if (-not $IncludeHubAndSpoke) { $files = @($files | Where-Object { $_ -notin $platformFiles }) }
    return @($files)
}

function Get-NormalizedText([string]$Path) {
    return [IO.File]::ReadAllText($Path).Replace("`r`n", "`n")
}

$masterFiles = Get-Managed $source
$targetFiles = Get-Managed $target
$drift = 0

foreach ($f in $masterFiles) {
    $dest = Join-Path $target $f
    $state = if (-not (Test-Path $dest)) { 'Missing' } elseif ((Get-NormalizedText (Join-Path $source $f)) -ne (Get-NormalizedText $dest)) { 'Different' } else { 'Same' }
    if ($state -eq 'Same') { continue }
    $drift++
    Write-Host ("{0,-9} {1}" -f $state, $f)
    if ($Apply) {
        $existingEol = if (Test-Path $dest) { if ([IO.File]::ReadAllText($dest).Contains("`r`n")) { "`r`n" } else { "`n" } } else { "`r`n" }
        New-Item -ItemType Directory -Path (Split-Path $dest) -Force | Out-Null
        [IO.File]::WriteAllText($dest, (Get-NormalizedText (Join-Path $source $f)).Replace("`n", $existingEol), (New-Object Text.UTF8Encoding($false)))
    }
}

foreach ($f in $targetFiles | Where-Object { $_ -notin $masterFiles }) {
    $drift++
    Write-Host ("{0,-9} {1}" -f 'Extra', $f)
    if ($Apply) { Remove-Item (Join-Path $target $f) -Force }
}

if ($Apply) {
    foreach ($d in $folders) {
        $dir = Join-Path $target $d
        if ((Test-Path $dir) -and -not (Get-ChildItem $dir -Recurse -File)) { Remove-Item $dir -Recurse -Force }
    }
    Write-Host "Applied $drift change(s) to $target."
    exit 0
}

if ($drift -eq 0) { Write-Host "No drift: $target matches the template."; exit 0 }
Write-Host "$drift file(s) differ. Re-run with -Apply to update $target."
exit 1
