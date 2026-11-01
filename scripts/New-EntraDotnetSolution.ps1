<#
.SYNOPSIS
Creates the Entra app registrations for a .NET solution (API, optional Web, optional E2E) and sets each project's .NET user-secrets.

.DESCRIPTION
Orchestrator only: calls entra/New-EntraAppRegistration.ps1 once per registration, then writes the returned IDs and secrets to the matching project's user-secrets with the lib/Dotnet.Common.ps1 helpers. The registration script never touches user-secrets, so every project is configured the same way.
Api: resource server that validates bearer tokens.
Web: Auth Code + PKCE interactive sign-in (Microsoft.Identity.Web), created when -WebAppRegistrationName is given.
E2E: client credentials machine/CI identity, created only with -IncludeE2E.
Safe to re-run: existing registrations are only added to, and secrets are created only for new registrations or with -RotateSecrets.
A secret that cannot be stored in user-secrets, or any secret with -ShowSecrets, is printed once and cannot be retrieved later.

.EXAMPLE
# API only (run from the repo root):
pwsh -File ./.azure/scripts/New-EntraDotnetSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -ApiProjectPath "./src/Presentation.Api"

.EXAMPLE
# API + Web (run from the repo root):
pwsh -File ./.azure/scripts/New-EntraDotnetSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -ApiProjectPath "./src/Presentation.Api" -WebProjectPath "./src/Presentation.Web" -GenerateSecrets

.EXAMPLE
# API + Web + E2E with auto-consent (run from the repo root):
pwsh -File ./.azure/scripts/New-EntraDotnetSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -E2EAppRegistrationName "myproduct-e2e-dev-001" -ApiProjectPath "./src/Presentation.Api" -WebProjectPath "./src/Presentation.Web" -E2EProjectPath "./src/Tests.Endtoend" -WebRedirectUri "https://localhost:7175/signin-oidc" -WebLogoutUri "https://localhost:7175/signout-callback-oidc" -IncludeE2E -GenerateSecrets -AutoConsent

.EXAMPLE
# Intentional secret rotation on existing apps (run from the repo root):
pwsh -File ./.azure/scripts/New-EntraDotnetSolution.ps1 -EntraInstanceUrl "https://your-tenant.ciamlogin.com" -TenantId "<tenant-id>" -ApiAppRegistrationName "myproduct-api-dev-001" -WebAppRegistrationName "myproduct-web-dev-001" -WebProjectPath "./src/Presentation.Web" -GenerateSecrets -RotateSecrets

.NOTES
- Requires Az.Accounts, Az.Resources, Microsoft.Graph.Applications and the .NET SDK.
- Relative project paths resolve from the current directory, not from this script's folder.
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
. "$PSScriptRoot\lib\Dotnet.Common.ps1"

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

function Invoke-Registration {
    param([hashtable]$Arguments, [string]$Label)
    try {
        $output = & "$PSScriptRoot\entra\New-EntraAppRegistration.ps1" @Arguments
    }
    catch {
        Write-Error "FATAL: $Label app registration failed. $($_.Exception.Message)"
        exit 1
    }
    $result = @($output) | Where-Object { $_ -and $_.PSObject.Properties['AppId'] } | Select-Object -Last 1
    if (-not $result) {
        Write-Error "FATAL: $Label app registration returned no AppId."
        exit 1
    }
    Write-Host "$Label app ready: $($result.AppId)"
    return $result
}

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
Save-DotnetUserSecrets -Label 'API' -ProjectPath $ApiProjectPath -ShowSecrets:$ShowSecrets -Secrets @{
    "EntraExternalId:Instance"          = $EntraInstanceUrl
    "EntraExternalId:TenantId"          = $TenantId
    "EntraExternalId:ClientId"          = $api.AppId
    "EntraExternalId:ValidateAuthority" = "true"
} | Out-Null

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
        ProjectName         = (Get-DotnetProjectName $WebProjectPath)
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
    Save-DotnetUserSecrets -Label 'Web' -ProjectPath $WebProjectPath -Secrets $webSecrets -ShowSecrets:$ShowSecrets | Out-Null
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
        ProjectName         = (Get-DotnetProjectName $E2EProjectPath)
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
    Save-DotnetUserSecrets -Label 'E2E' -ProjectPath $E2EProjectPath -Secrets $e2eSecrets -ShowSecrets:$ShowSecrets | Out-Null
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
    & "$PSScriptRoot\entra\Grant-EntraConsent.ps1" @consentParams
}
else {
    Write-Host ""
    Write-Host "Step 4: Skipping consent step (no Web app registered)."
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  New-EntraDotnetSolution Complete" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Tenant:       $TenantId"
Write-Host "  Instance:     $EntraInstanceUrl"
Write-Host ""
Write-Host "  API  ($($api.Type)): $($api.AppId)  [Created=$($api.Created)]"
if ($web) { Write-Host "  Web  ($($web.Type)): $($web.AppId)  [Created=$($web.Created)]" }
if ($e2e) { Write-Host "  E2E  ($($e2e.Type)): $($e2e.AppId)  [Created=$($e2e.Created)]" }
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green
