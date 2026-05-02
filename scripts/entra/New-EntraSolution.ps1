# ============================================================================
# Script Name:   New-EntraSolution.ps1
# Description:   Orchestrator — sets up Entra App Registrations for a .NET
#                solution with 1-3 projects: API (resource server), Web App
#                (interactive user auth), and optional E2E / CI automation.
# -----------------------------------------------------------------------------
# Personas:
#   API  → Resource server: validates bearer tokens (no interactive sign-in)
#   Web  → Auth Code + PKCE: interactive human sign-in (Microsoft.Identity.Web)
#   E2E  → Client Credentials: machine/CI identity (opt-in via -IncludeE2E)
# -----------------------------------------------------------------------------
# Example — API only (minimal):
#   pwsh -File ./New-EntraSolution.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<tenant-id>" `
#       -ApiAppRegistrationName "myproduct-api-dev-001" `
#       -ApiProjectPath "../../src/Presentation.WebApi"
#
# Example — API + Web (standard):
#   pwsh -File ./New-EntraSolution.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<tenant-id>" `
#       -ApiAppRegistrationName "myproduct-api-dev-001" `
#       -WebAppRegistrationName "myproduct-web-dev-001" `
#       -ApiProjectPath "../../src/Presentation.WebApi" `
#       -WebProjectPath "../../src/Presentation.Blazor" `
#       -GenerateSecrets
#
# Example — rerun idempotently after interruption (no secret duplication):
#   pwsh -File ./New-EntraSolution.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<tenant-id>" `
#       -ApiAppRegistrationName "myproduct-api-dev-001" `
#       -WebAppRegistrationName "myproduct-web-dev-001" `
#       -IncludeE2E -E2EAppRegistrationName "myproduct-e2e-dev-001" `
#       -GenerateSecrets
#
# Example — intentional secret rotation on existing apps:
#   pwsh -File ./New-EntraSolution.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<tenant-id>" `
#       -ApiAppRegistrationName "myproduct-api-dev-001" `
#       -WebAppRegistrationName "myproduct-web-dev-001" `
#       -IncludeE2E -E2EAppRegistrationName "myproduct-e2e-dev-001" `
#       -GenerateSecrets -RotateSecrets
#
# Example — API + Web + E2E (full, with auto-consent):
#   pwsh -File ./New-EntraSolution.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<tenant-id>" `
#       -ApiAppRegistrationName "myproduct-api-dev-001" `
#       -WebAppRegistrationName "myproduct-web-dev-001" `
#       -E2EAppRegistrationName "myproduct-e2e-dev-001" `
#       -ApiProjectPath "../../src/Presentation.Api" `
#       -WebProjectPath "../../src/Presentation.Web" `
#       -E2EProjectPath "../../src/Tests.Endtoend" `
#       -WebRedirectUri "https://localhost:7175/signin-oidc" `
#       -WebLogoutUri "https://localhost:7175/signout-callback-oidc" `
#       -IncludeE2E -GenerateSecrets -RotateSecrets -AutoConsent
# -----------------------------------------------------------------------------
# Notes:
#   - Requires Az.Accounts, Az.Resources, Microsoft.Graph.Applications
#   - Each child script is idempotent and can also be run independently
#   - Secrets are never generated unless -GenerateSecrets is specified
#   - E2E registration is never created unless -IncludeE2E is specified
# ============================================================================
param(
    [Parameter(Mandatory)][string]$EntraInstanceUrl,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ApiAppRegistrationName,

    # Web app (Auth Code + PKCE) — required unless you only need an API
    [string]$WebAppRegistrationName = "",
    [string]$WebProjectPath         = "",
    [string]$WebRedirectUri         = "https://localhost:7175/signin-oidc",
    [string]$WebLogoutUri           = "https://localhost:7175/signout-callback-oidc",

    # E2E / CI (Client Credentials) — opt-in only
    [switch]$IncludeE2E,
    [string]$E2EAppRegistrationName = "",
    [string]$E2EProjectPath         = "",

    # Project paths
    [string]$ApiProjectPath         = "",

    # Secrets — gated to prevent credential sprawl
    [switch]$GenerateSecrets,
    [switch]$RotateSecrets,

    # Admin consent — print URLs by default; programmatic grant with -AutoConsent
    [switch]$AutoConsent,

    [string]$DotNetVersion          = "10"
)

# ── Prerequisites (idempotent — each child also checks, but run once here) ────
Write-Host "Checking prerequisites..."
$dotnetInstalled = & dotnet --list-sdks 2>$null | Select-String "^$DotNetVersion\."
if (-not $dotnetInstalled) {
    Write-Host ".NET SDK $DotNetVersion not found. Installing via winget..."
    winget install --id Microsoft.DotNet.SDK.$DotNetVersion -e --silent
}
else {
    Write-Host ".NET SDK $DotNetVersion is already installed."
}
$modules = @("Az.Accounts", "Az.Resources", "Microsoft.Graph.Applications")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing PowerShell module: $module"
        Install-Module $module -Scope CurrentUser -Force
    }
    else {
        Write-Host "PowerShell module $module is already installed."
    }
}
Import-Module Az.Accounts               -ErrorAction Stop
Import-Module Az.Resources              -ErrorAction Stop
Import-Module Microsoft.Graph.Applications -ErrorAction Stop

# ── Validate E2E inputs ───────────────────────────────────────────────────────
if ($IncludeE2E -and [string]::IsNullOrWhiteSpace($E2EAppRegistrationName)) {
    Write-Error "FATAL: -IncludeE2E requires -E2EAppRegistrationName."
    exit 1
}

# ── Derive child script paths ─────────────────────────────────────────────────
$authDir = Join-Path $PSScriptRoot "auth"

# ── Step 1: API app (resource server) ─────────────────────────────────────────
Write-Host ""
Write-Host "──────────────────────────────────────────────────"
Write-Host " Step 1: API App Registration (resource server)"
Write-Host "──────────────────────────────────────────────────"
$api = & "$authDir\New-EntraApiApp.ps1" `
    -EntraInstanceUrl    $EntraInstanceUrl `
    -TenantId            $TenantId `
    -AppRegistrationName $ApiAppRegistrationName `
    -ProjectPath         $ApiProjectPath

if (-not $api -or -not $api.AppId) {
    Write-Error "FATAL: API app registration failed."
    exit 1
}
Write-Host "API app ready: $($api.AppId)"

# ── Step 2: Web app (Auth Code + PKCE, optional) ──────────────────────────────
$web = $null
if (-not [string]::IsNullOrWhiteSpace($WebAppRegistrationName)) {
    Write-Host ""
    Write-Host "──────────────────────────────────────────────────"
    Write-Host " Step 2: Web App Registration (Auth Code + PKCE)"
    Write-Host "──────────────────────────────────────────────────"
    $web = & "$authDir\New-EntraWebApp.ps1" `
        -EntraInstanceUrl    $EntraInstanceUrl `
        -TenantId            $TenantId `
        -AppRegistrationName $WebAppRegistrationName `
        -ApiAppId            $api.AppId `
        -ProjectPath         $WebProjectPath `
        -RedirectUri         $WebRedirectUri `
        -LogoutUri           $WebLogoutUri `
        -GenerateSecrets:$GenerateSecrets `
        -RotateSecret:$RotateSecrets

    if (-not $web -or -not $web.AppId) {
        Write-Error "FATAL: Web app registration failed."
        exit 1
    }
    Write-Host "Web app ready: $($web.AppId)"
}
else {
    Write-Host ""
    Write-Host "Step 2: Skipping Web app (no -WebAppRegistrationName provided)."
}

# ── Step 3: E2E app (Client Credentials, explicit opt-in) ─────────────────────
$e2e = $null
if ($IncludeE2E) {
    Write-Host ""
    Write-Host "──────────────────────────────────────────────────"
    Write-Host " Step 3: E2E App Registration (Client Credentials)"
    Write-Host "──────────────────────────────────────────────────"
    $e2e = & "$authDir\New-EntraE2EApp.ps1" `
        -TenantId            $TenantId `
        -AppRegistrationName $E2EAppRegistrationName `
        -ApiAppId            $api.AppId `
        -ProjectPath         $E2EProjectPath `
        -GenerateSecrets:$GenerateSecrets `
        -RotateSecret:$RotateSecrets

    if (-not $e2e -or -not $e2e.AppId) {
        Write-Error "FATAL: E2E app registration failed."
        exit 1
    }
    Write-Host "E2E app ready: $($e2e.AppId)"
}
else {
    Write-Host ""
    Write-Host "Step 3: Skipping E2E app (-IncludeE2E not specified)."
    Write-Host "        Re-run with -IncludeE2E to add machine/CI credentials."
}

# ── Step 4: Admin consent (centralized) ───────────────────────────────────────
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
    & "$authDir\Grant-EntraConsent.ps1" @consentParams
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
if ($web) {
    Write-Host "  Web  ($($web.Type)): $($web.AppId)  [Created=$($web.Created)]"
    if ($web.Secret) {
        Write-Host "  Web Secret: (already printed above — store in Key Vault)" -ForegroundColor Yellow
    }
}
if ($e2e) {
    Write-Host "  E2E  ($($e2e.Type)): $($e2e.AppId)  [Created=$($e2e.Created)]"
    if ($e2e.Secret) {
        Write-Host "  E2E Secret: (already printed above — store in Key Vault / CI secret store)" -ForegroundColor Yellow
    }
}
Write-Host "══════════════════════════════════════════════════" -ForegroundColor Green