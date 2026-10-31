<#
.SYNOPSIS
Orchestrator: creates the Entra app registrations for a .NET solution (API, optional Web, optional E2E) and sets each project's .NET user-secrets.

.DESCRIPTION
Calls New-EntraAppRegistration.ps1 once per registration, then writes the returned IDs and secrets to the matching project's user-secrets. The registration script never touches user-secrets, so every project is configured the same way.
Api: resource server that validates bearer tokens.
Web: Auth Code + PKCE interactive sign-in (Microsoft.Identity.Web), created when -WebAppRegistrationName is given.
E2E: client credentials machine/CI identity, created only with -IncludeE2E.
Safe to re-run: existing registrations are only added to, and secrets are created only for new registrations or with -RotateSecrets.
A secret that cannot be stored in user-secrets, or any secret with -ShowSecrets, is printed once and cannot be retrieved later.

.EXAMPLE
# API only (minimal):
pwsh -File ./New-EntraSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -ApiProjectPath "../../src/Presentation.Api"

.EXAMPLE
# API + Web (standard):
pwsh -File ./New-EntraSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -ApiProjectPath "../../src/Presentation.Api" -WebProjectPath "../../src/Presentation.Web" -GenerateSecrets

.EXAMPLE
# API + Web + E2E with auto-consent:
pwsh -File ./New-EntraSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -E2EAppRegistrationName "myproduct-e2e-dev-001" -ApiProjectPath "../../src/Presentation.Api" -WebProjectPath "../../src/Presentation.Web" -E2EProjectPath "../../src/Tests.Endtoend" -WebRedirectUri "https://localhost:7175/signin-oidc" -WebLogoutUri "https://localhost:7175/signout-callback-oidc" -IncludeE2E -GenerateSecrets -AutoConsent

.EXAMPLE
# Intentional secret rotation on existing apps:
pwsh -File ./New-EntraSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -WebProjectPath "../../src/Presentation.Web" -GenerateSecrets -RotateSecrets

.NOTES
- Requires Az.Accounts, Az.Resources, Microsoft.Graph.Applications and the .NET SDK.
- Relative project paths resolve from this script's folder.
- Secrets are never generated unless -GenerateSecrets is specified.
- The E2E registration is never created unless -IncludeE2E is specified.
#>
param(
    [Parameter(Mandatory)][string]$EntraInstanceUrl,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ApiAppRegistrationName,

    # Web app (Auth Code + PKCE), optional
    [string]$WebAppRegistrationName = "",
    [string]$WebProjectPath         = "",
    [string]$WebRedirectUri         = "https://localhost:7175/signin-oidc",
    [string]$WebLogoutUri           = "https://localhost:7175/signout-callback-oidc",
    [string]$ResetUserFlowName      = "",

    # E2E / CI (Client Credentials), opt-in only
    [switch]$IncludeE2E,
    [string]$E2EAppRegistrationName = "",
    [string]$E2EProjectPath         = "",

    [string]$ApiProjectPath         = "",

    # Secrets are gated to prevent credential sprawl
    [switch]$GenerateSecrets,
    [switch]$RotateSecrets,
    [switch]$ShowSecrets,

    # Admin consent: print URLs by default, grant programmatically with -AutoConsent
    [switch]$AutoConsent,

    [string]$DotNetVersion          = "10"
)

$ErrorActionPreference = 'Stop'

if ($IncludeE2E -and [string]::IsNullOrWhiteSpace($E2EAppRegistrationName)) {
    Write-Error "FATAL: -IncludeE2E requires -E2EAppRegistrationName."
    exit 1
}

# ── .NET SDK (needed for user-secrets); modules are handled by the registration script ─
$dotnetInstalled = & dotnet --list-sdks 2>$null | Select-String "^$DotNetVersion\."
if (-not $dotnetInstalled) {
    Write-Host ".NET SDK $DotNetVersion not found. Installing via winget..."
    winget install --id Microsoft.DotNet.SDK.$DotNetVersion -e --silent
}

# ── Helpers ───────────────────────────────────────────────────────────────────
function Show-Secrets {
    param([hashtable]$Secrets)
    foreach ($key in $Secrets.Keys) {
        if ($key -match 'Secret|Password' -and -not [string]::IsNullOrWhiteSpace([string]$Secrets[$key])) {
            Write-Host "  $key = $($Secrets[$key])" -ForegroundColor Yellow
        }
    }
}

function Get-ProjectName([string]$ProjectPath) {
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { return '' }
    $leaf = Split-Path $ProjectPath.TrimEnd('\', '/') -Leaf
    if ($leaf -like '*.csproj') { $leaf = [IO.Path]::GetFileNameWithoutExtension($leaf) }
    return $leaf
}

# Returns $true when the values were written to the project's user-secrets.
function Set-ProjectUserSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets)
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { return $false }
    $resolvedPath = Resolve-Path -Path $ProjectPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Warning "*** Project path '$ProjectPath' not found. Skipping dotnet user-secrets. ***"
        return $false
    }

    $targetPath = $resolvedPath.Path
    $projectFile = $null
    if ((Test-Path $targetPath -PathType Leaf) -and $targetPath.EndsWith('.csproj', [System.StringComparison]::OrdinalIgnoreCase)) {
        $projectFile = $targetPath
    }
    elseif (Test-Path $targetPath -PathType Container) {
        $project = Get-ChildItem -Path $targetPath -Filter "*.csproj" -File | Select-Object -First 1
        if ($project) { $projectFile = $project.FullName }
    }
    if (-not $projectFile) {
        Write-Warning "*** No .csproj found at '$targetPath'. Skipping dotnet user-secrets. ***"
        return $false
    }

    Write-Host "Setting .NET user-secrets for project: $projectFile"
    dotnet user-secrets init --project "$projectFile" | Out-Null
    foreach ($key in $Secrets.Keys) {
        dotnet user-secrets set "$key" "$($Secrets[$key])" --project "$projectFile" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "*** Failed to set '$key' in user-secrets. ***"
            return $false
        }
        Write-Host "  Set: $key"
    }
    return $true
}

# Writes the values to user-secrets, or shows the secret ones once when that is not possible.
function Save-ProjectSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets, [string]$Label)
    $stored = Set-ProjectUserSecrets -ProjectPath $ProjectPath -Secrets $Secrets
    if (-not $stored) {
        Write-Warning "*** $Label secrets were not stored. Secret values are shown only once below; copy them now. ***"
        Show-Secrets -Secrets $Secrets
    }
    elseif ($ShowSecrets) {
        Write-Host "$Label secrets (shown once, for CI or Key Vault):" -ForegroundColor Yellow
        Show-Secrets -Secrets $Secrets
    }
}

function Invoke-Registration {
    param([hashtable]$Arguments, [string]$Label)
    Push-Location $PSScriptRoot
    try {
        $output = & "$PSScriptRoot\New-EntraAppRegistration.ps1" @Arguments
    }
    catch {
        Write-Error "FATAL: $Label app registration failed. $($_.Exception.Message)"
        exit 1
    }
    finally {
        Pop-Location
    }
    $result = @($output) | Where-Object { $_ -and $_.PSObject.Properties['AppId'] } | Select-Object -Last 1
    if (-not $result) {
        Write-Error "FATAL: $Label app registration returned no AppId."
        exit 1
    }
    Write-Host "$Label app ready: $($result.AppId)"
    return $result
}

$authDir = Join-Path $PSScriptRoot "auth"

# ── Step 1: API app ───────────────────────────────────────────────────────────
Write-Host ""
Write-Host "──────────────────────────────────────────────────"
Write-Host " Step 1: API App Registration (resource server)"
Write-Host "──────────────────────────────────────────────────"
$api = Invoke-Registration -Label 'API' -Arguments @{
    Type                = 'Api'
    TenantId            = $TenantId
    AppRegistrationName = $ApiAppRegistrationName
}
Save-ProjectSecrets -Label 'API' -ProjectPath $ApiProjectPath -Secrets @{
    "EntraExternalId:Instance"          = $EntraInstanceUrl
    "EntraExternalId:TenantId"          = $TenantId
    "EntraExternalId:ClientId"          = $api.AppId
    "EntraExternalId:ValidateAuthority" = "true"
}

# ── Step 2: Web app ───────────────────────────────────────────────────────────
$web = $null
if (-not [string]::IsNullOrWhiteSpace($WebAppRegistrationName)) {
    Write-Host ""
    Write-Host "──────────────────────────────────────────────────"
    Write-Host " Step 2: Web App Registration (Auth Code + PKCE)"
    Write-Host "──────────────────────────────────────────────────"
    $webArgs = @{
        Type                = 'Web'
        TenantId            = $TenantId
        AppRegistrationName = $WebAppRegistrationName
        ApiAppId            = $api.AppId
        RedirectUris        = @($WebRedirectUri)
        LogoutUri           = $WebLogoutUri
        ProjectName         = (Get-ProjectName $WebProjectPath)
        SkipPrerequisites   = $true
    }
    if ($GenerateSecrets) { $webArgs.GenerateSecret = $true }
    if ($RotateSecrets) { $webArgs.RotateSecret = $true }
    $web = Invoke-Registration -Label 'Web' -Arguments $webArgs

    $webSecrets = @{
        "BackendApi:ClientId"               = $api.AppId
        "EntraExternalId:Instance"          = $EntraInstanceUrl
        "EntraExternalId:TenantId"          = $TenantId
        "EntraExternalId:ClientId"          = $web.AppId
        "EntraExternalId:ValidateAuthority" = "true"
    }
    if ($web.Secret) { $webSecrets["EntraExternalId:ClientSecret"] = $web.Secret }
    if (-not [string]::IsNullOrWhiteSpace($ResetUserFlowName)) {
        $webSecrets["EntraExternalId:PasswordResetUrl"] = "$($EntraInstanceUrl.TrimEnd('/'))/$TenantId/oauth2/v2.0/authorize?p=$ResetUserFlowName"
    }
    Save-ProjectSecrets -Label 'Web' -ProjectPath $WebProjectPath -Secrets $webSecrets
}
else {
    Write-Host ""
    Write-Host "Step 2: Skipping Web app (no -WebAppRegistrationName provided)."
}

# ── Step 3: E2E app ───────────────────────────────────────────────────────────
$e2e = $null
if ($IncludeE2E) {
    Write-Host ""
    Write-Host "──────────────────────────────────────────────────"
    Write-Host " Step 3: E2E App Registration (Client Credentials)"
    Write-Host "──────────────────────────────────────────────────"
    $e2eArgs = @{
        Type                = 'E2E'
        TenantId            = $TenantId
        AppRegistrationName = $E2EAppRegistrationName
        ApiAppId            = $api.AppId
        ProjectName         = (Get-ProjectName $E2EProjectPath)
        SkipPrerequisites   = $true
    }
    if ($GenerateSecrets) { $e2eArgs.GenerateSecret = $true }
    if ($RotateSecrets) { $e2eArgs.RotateSecret = $true }
    $e2e = Invoke-Registration -Label 'E2E' -Arguments $e2eArgs

    $e2eSecrets = @{
        "EntraExternalId:Instance" = $EntraInstanceUrl
        "EntraExternalId:TenantId" = $TenantId
        "EntraExternalId:ClientId" = $e2e.AppId
        "BackendApi:ClientId"      = $api.AppId
    }
    if ($e2e.Secret) { $e2eSecrets["EntraExternalId:ClientSecret"] = $e2e.Secret }
    Save-ProjectSecrets -Label 'E2E' -ProjectPath $E2EProjectPath -Secrets $e2eSecrets
}
else {
    Write-Host ""
    Write-Host "Step 3: Skipping E2E app (-IncludeE2E not specified)."
    Write-Host "        Re-run with -IncludeE2E to add machine/CI credentials."
}

# ── Step 4: Admin consent ─────────────────────────────────────────────────────
if ($web) {
    Write-Host ""
    Write-Host "──────────────────────────────────────────────────"
    Write-Host " Step 4: Admin Consent"
    Write-Host "──────────────────────────────────────────────────"
    $consentParams = @{
        TenantId    = $TenantId
        ApiAppId    = $api.AppId
        WebAppId    = $web.AppId
        AutoConsent = $AutoConsent
    }
    if ($e2e) { $consentParams["E2EAppId"] = $e2e.AppId }
    Push-Location $PSScriptRoot
    try { & "$authDir\Grant-EntraConsent.ps1" @consentParams }
    finally { Pop-Location }
}
else {
    Write-Host ""
    Write-Host "Step 4: Skipping consent step (no Web app registered)."
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  New-EntraSolution Complete" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Tenant:       $TenantId"
Write-Host "  Instance:     $EntraInstanceUrl"
Write-Host ""
Write-Host "  API  ($($api.Type)): $($api.AppId)  [Created=$($api.Created)]"
if ($web) { Write-Host "  Web  ($($web.Type)): $($web.AppId)  [Created=$($web.Created)]" }
if ($e2e) { Write-Host "  E2E  ($($e2e.Type)): $($e2e.AppId)  [Created=$($e2e.Created)]" }
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
