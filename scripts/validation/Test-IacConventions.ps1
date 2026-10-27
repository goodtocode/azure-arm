# ============================================================================
# Script Name:   Test-IacConventions.ps1
# Description:   Enforces the repo slot system and compiles every template
#                and parameter file. Exits 1 on any violation.
# -----------------------------------------------------------------------------
# Slots (see README "Slot system"):
#   Template  : workload-{archetype}[-zerotrust].bicep
#               platform-[(hub|spoke|shared)-]{capability}[-{variant}].bicep
#   Variables : workload-{archetype}-{mode}-{env}.bicepparam
#               platform-{template slots}-{env}.bicepparam
#   mode      : standalone | shared | network | zerotrust
#   env       : dev | test | stage | prod      (platform also allows plat)
# -----------------------------------------------------------------------------
# Example:
#   pwsh -File ./scripts/validation/Test-IacConventions.ps1
#   pwsh -File ./scripts/validation/Test-IacConventions.ps1 -SkipCompile
# ============================================================================
[CmdletBinding()]
param(
    [string]$BicepRoot = (Join-Path $PSScriptRoot '../../bicep'),
    [switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'
$workloadArchetypes = @('digitalproduct', 'usermachines')
$archetypeModes = @{
    digitalproduct = @('standalone', 'shared', 'network', 'zerotrust')
    usermachines   = @('standalone', 'network', 'zerotrust')
}
$modes = @('standalone', 'shared', 'network', 'zerotrust')
$envs = @('dev', 'test', 'stage', 'prod')
$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Violation([string]$Message) { $script:errors.Add($Message) }

$templatesDir = Join-Path $BicepRoot 'templates'
$variablesDir = Join-Path $BicepRoot 'variables'
$modulesDir = Join-Path $BicepRoot 'modules'

# --- Templates ---------------------------------------------------------------
$templates = Get-ChildItem $templatesDir -Filter *.bicep -File
foreach ($t in $templates) {
    $base = $t.BaseName
    if ($base -match '^workload-') {
        if ($base -notmatch '^workload-(?<arch>[a-z0-9]+)(?<zt>-zerotrust)?$') {
            Add-Violation "Template '$($t.Name)' must match workload-{archetype}[-zerotrust].bicep"
        }
        elseif ($Matches.arch -notin $workloadArchetypes) {
            Add-Violation "Template '$($t.Name)' uses unknown archetype '$($Matches.arch)'. Known: $($workloadArchetypes -join ', ')"
        }
    }
    elseif ($base -match '^platform-') {
        if ($base -notmatch '^platform-((hub|spoke|shared)-)?[a-z0-9]+(-[a-z0-9]+)*$') {
            Add-Violation "Template '$($t.Name)' must match platform-[(hub|spoke|shared)-]{capability}[-{variant}].bicep"
        }
    }
    else {
        Add-Violation "Template '$($t.Name)' must start with 'platform-' or 'workload-'"
    }
}

# --- Variables ---------------------------------------------------------------
$params = Get-ChildItem $variablesDir -Filter *.bicepparam -File
foreach ($p in $params) {
    $base = $p.BaseName
    $using = Select-String -Path $p.FullName -Pattern "^\s*using\s+'(?<path>[^']+)'" | Select-Object -First 1
    if (-not $using) { Add-Violation "Variables '$($p.Name)' has no using statement"; continue }
    $templateName = [IO.Path]::GetFileNameWithoutExtension($using.Matches[0].Groups['path'].Value)
    if (-not (Test-Path (Join-Path $templatesDir "$templateName.bicep"))) {
        Add-Violation "Variables '$($p.Name)' uses missing template '$templateName.bicep'"
        continue
    }

    if ($base -match '^workload-') {
        $pattern = '^workload-(?<arch>[a-z0-9]+)-(?<mode>' + ($modes -join '|') + ')-(?<env>' + ($envs -join '|') + ')$'
        if ($base -notmatch $pattern) {
            Add-Violation "Variables '$($p.Name)' must match workload-{archetype}-{mode}-{env}.bicepparam (mode: $($modes -join '|'); env: $($envs -join '|'))"
            continue
        }
        $fileMode = $Matches.mode
        $allowedModes = $archetypeModes[$Matches.arch]
        if ($allowedModes -and $fileMode -notin $allowedModes) {
            Add-Violation "Variables '$($p.Name)': archetype '$($Matches.arch)' supports modes $($allowedModes -join ', ')"
        }
        $expected = if ($fileMode -eq 'zerotrust') { "workload-$($Matches.arch)-zerotrust" } else { "workload-$($Matches.arch)" }
        if ($templateName -ne $expected) {
            Add-Violation "Variables '$($p.Name)' mode '$fileMode' must use template '$expected.bicep', found '$templateName.bicep'"
        }
        if ($fileMode -ne 'zerotrust') {
            $modeLine = Select-String -Path $p.FullName -Pattern "^\s*param\s+mode\s*=\s*'(?<m>[^']+)'" | Select-Object -First 1
            if (-not $modeLine -or $modeLine.Matches[0].Groups['m'].Value -ne $fileMode) {
                Add-Violation "Variables '$($p.Name)' must set param mode = '$fileMode'"
            }
        }
    }
    elseif ($base -match '^platform-') {
        $pattern = '^' + [regex]::Escape($templateName) + '-(' + (($envs + 'plat') -join '|') + ')$'
        if ($base -notmatch $pattern) {
            Add-Violation "Variables '$($p.Name)' must be '$templateName-{env}.bicepparam' (env: $(($envs + 'plat') -join '|'))"
        }
    }
    else {
        Add-Violation "Variables '$($p.Name)' must start with 'platform-' or 'workload-'"
    }
}

foreach ($t in $templates) {
    $usedBy = $params | Where-Object {
        Select-String -Path $_.FullName -Pattern "using\s+'\.\./templates/$([regex]::Escape($t.BaseName))\.bicep'" -Quiet
    }
    if (-not $usedBy) { $warnings.Add("Template '$($t.Name)' has no variables file") }
}

# --- Modules -----------------------------------------------------------------
foreach ($m in Get-ChildItem $modulesDir -Filter *.bicep -File) {
    if ($m.BaseName -cnotmatch '^[a-z0-9]+-[a-z0-9]+$') {
        $warnings.Add("Module '$($m.Name)' should match {abbreviation}-{resourcename}.bicep in lowercase")
    }
}

# --- Compile -----------------------------------------------------------------
if (-not $SkipCompile) {
    foreach ($t in $templates) {
        $out = az bicep build --stdout --file $t.FullName 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { Add-Violation "Template '$($t.Name)' failed to compile:`n$out" }
    }
    foreach ($p in $params) {
        $out = az bicep build-params --stdout --file $p.FullName 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { Add-Violation "Variables '$($p.Name)' failed to compile:`n$out" }
    }
}

$warnings | ForEach-Object { Write-Warning $_ }
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Host "[FAIL] $_" -ForegroundColor Red }
    exit 1
}
Write-Host "[OK] $($templates.Count) templates, $($params.Count) variables files conform." -ForegroundColor Green
