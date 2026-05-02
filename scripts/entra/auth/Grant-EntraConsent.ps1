# ============================================================================
# Script Name:   Grant-EntraConsent.ps1
# Description:   Centralized admin consent for Entra App Registrations.
#                Prints portal URLs for manual consent (default) or attempts
#                programmatic grant when -AutoConsent is specified.
#                Designed to be called after all app registrations are created.
# -----------------------------------------------------------------------------
# Why centralized?
#   Admin consent is environment-dependent, often delayed, and sometimes
#   automated. Isolating it here prevents duplication and enables deferred
#   or automated grant without touching registration scripts.
# -----------------------------------------------------------------------------
# Example CLI Usage (standalone):
#   pwsh -File ./Grant-EntraConsent.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -ApiAppId "<api-app-client-id>" `
#       -WebAppId "<web-app-client-id>"
#
# With E2E:
#   pwsh -File ./Grant-EntraConsent.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -ApiAppId "<api-app-client-id>" `
#       -WebAppId "<web-app-client-id>" `
#       -E2EAppId "<e2e-app-client-id>"
#
# Programmatic grant (requires AppRoleAssignment.ReadWrite.All):
#   pwsh -File ./Grant-EntraConsent.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -ApiAppId "<api-app-client-id>" `
#       -WebAppId "<web-app-client-id>" `
#       -AutoConsent
# -----------------------------------------------------------------------------
# Example (called from orchestrator):
#   $consentApps = @($api, $web)
#   if ($IncludeE2E) { $consentApps += $e2e }
#   & "$PSScriptRoot\auth\Grant-EntraConsent.ps1" `
#       -TenantId $TenantId `
#       -ApiAppId $api.AppId `
#       -WebAppId $web.AppId `
#       -E2EAppId ($e2e ? $e2e.AppId : $null) `
#       -AutoConsent:$AutoConsent
# ============================================================================
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$ApiAppId,
    [Parameter(Mandatory)][string]$WebAppId,
    [string]$E2EAppId    = "",
    [switch]$AutoConsent
)

# ── Shared helpers ────────────────────────────────────────────────────────────

function Install-Prerequisites {
    $modules = @(
        "Az.Accounts",
        "Microsoft.Graph.Applications",
        "Microsoft.Graph.Identity.SignIns"
    )
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing PowerShell module: $module"
            Install-Module $module -Scope CurrentUser -Force
        }
        else {
            Write-Host "PowerShell module $module is already installed."
        }
    }
    Import-Module Az.Accounts                    -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications   -ErrorAction Stop
    Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
}

function Connect-EntraSession {
    param([string]$TenantId)

    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
        Write-Host "Logging into Azure tenant $TenantId..."
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }
    else {
        Write-Host "Already authenticated to Azure tenant $TenantId."
    }

    $mgContext = $null
    try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}

    # AutoConsent requires elevated Graph scopes
    $scopes = if ($AutoConsent) {
        @("Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All", "AppRoleAssignment.ReadWrite.All")
    } else {
        @("Application.Read.All")
    }

    $hasRequiredScopes = $false
    if ($mgContext -and $mgContext.Scopes) {
        $hasRequiredScopes = ($scopes | Where-Object { $_ -notin $mgContext.Scopes }).Count -eq 0
    }

    if (-not $mgContext -or $mgContext.TenantId -ne $TenantId -or -not $hasRequiredScopes) {
        Write-Host "Connecting to Microsoft Graph..."
        try {
            Connect-MgGraph -TenantId $TenantId -Scopes $scopes -NoWelcome | Out-Null
            $mgContext = Get-MgContext -ErrorAction Stop
        }
        catch {
            Write-Error "FATAL: Microsoft Graph authentication failed. $($_.Exception.Message)"
            exit 1
        }

        if (-not $mgContext -or $mgContext.TenantId -ne $TenantId) {
            Write-Error "FATAL: Microsoft Graph authentication did not produce a valid tenant context."
            exit 1
        }
        Write-Host "Connected to Microsoft Graph."
    }
    else {
        Write-Host "Already connected to Microsoft Graph for tenant $TenantId."
    }
}

function Get-ConsentUrl {
    param([string]$AppId)
    return "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Permissions/appId/$AppId/isMSAApp~/false"
}

function Grant-DelegatedConsent {
    param(
        [string]$ServicePrincipalId,
        [string]$ResourceSpId,
        [string[]]$Scopes
    )

    if (-not (Get-Command Get-MgOauth2PermissionGrant -ErrorAction SilentlyContinue) -or
        -not (Get-Command New-MgOauth2PermissionGrant -ErrorAction SilentlyContinue)) {
        Write-Error "FATAL: OAuth2 permission grant cmdlets are unavailable. Ensure Microsoft.Graph.Identity.SignIns is installed and imported."
        exit 1
    }

    $scopeString = $Scopes -join " "
    try {
        $existing = Get-MgOauth2PermissionGrant -Filter "clientId eq '$ServicePrincipalId' and resourceId eq '$ResourceSpId'" -ErrorAction Stop |
            Select-Object -First 1

        if ($existing) {
            Update-MgOauth2PermissionGrant -OAuth2PermissionGrantId $existing.Id -Scope $scopeString -ErrorAction Stop | Out-Null
            Write-Host "  Updated delegated consent: $scopeString"
        }
        else {
            New-MgOauth2PermissionGrant -ClientId $ServicePrincipalId -ConsentType AllPrincipals `
                -ResourceId $ResourceSpId -Scope $scopeString -ErrorAction Stop | Out-Null
            Write-Host "  Granted delegated consent: $scopeString"
        }
    }
    catch {
        Write-Error "FATAL: Failed to grant delegated consent '$scopeString'. $($_.Exception.Message)"
        exit 1
    }
}

# ── Prerequisites & authentication ───────────────────────────────────────────
Install-Prerequisites
Connect-EntraSession -TenantId $TenantId

# ── Resolve service principals ────────────────────────────────────────────────
Write-Host ""
Write-Host "=== Admin Consent: resolving app registrations ==="
$webSp  = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $WebAppId } | Select-Object -First 1
$apiSp  = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $ApiAppId } | Select-Object -First 1
$e2eSp  = if ($E2EAppId) {
    Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $E2EAppId } | Select-Object -First 1
} else { $null }

if (-not $webSp) { Write-Error "FATAL: Web app service principal not found for AppId $WebAppId."; exit 1 }
if (-not $apiSp) { Write-Error "FATAL: API app service principal not found for AppId $ApiAppId."; exit 1 }

$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop

if ($AutoConsent) {
    # ── Programmatic consent ──────────────────────────────────────────────────
    Write-Host ""
    Write-Host "Granting admin consent programmatically..." -ForegroundColor Yellow

    # Web → Microsoft Graph (User.Read, email, profile)
    Write-Host "  Web app → Microsoft Graph delegated scopes..."
    Grant-DelegatedConsent -ServicePrincipalId $webSp.Id -ResourceSpId $msGraphSp.Id `
        -Scopes @("User.Read", "email", "profile")

    # Web → API (access_as_user, assets.read, assets.edit, assets.delete)
    Write-Host "  Web app → API delegated scopes..."
    Grant-DelegatedConsent -ServicePrincipalId $webSp.Id -ResourceSpId $apiSp.Id `
        -Scopes @("access_as_user", "assets.read", "assets.edit", "assets.delete")

    # API → Microsoft Graph (User.Read)
    Write-Host "  API app → Microsoft Graph delegated scope..."
    Grant-DelegatedConsent -ServicePrincipalId $apiSp.Id -ResourceSpId $msGraphSp.Id `
        -Scopes @("User.Read")

    # E2E — application role assignment already handled by New-EntraE2EApp.ps1
    if ($e2eSp) {
        Write-Host "  E2E app role assignments are managed by New-EntraE2EApp.ps1 (Asset.Automation)."
    }

    Write-Host "Programmatic admin consent complete." -ForegroundColor Green
}
else {
    # ── Manual consent instructions ───────────────────────────────────────────
    Write-Host ""
    Write-Host "======================================================" -ForegroundColor Yellow
    Write-Host " ACTION REQUIRED: Grant admin consent in Azure Portal " -ForegroundColor Yellow
    Write-Host "======================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Open each URL below, then click 'Grant admin consent for <tenant>':" -ForegroundColor White
    Write-Host ""

    Write-Host "1) API App ($ApiAppId):" -ForegroundColor Cyan
    Write-Host "   $(Get-ConsentUrl -AppId $ApiAppId)" -ForegroundColor White
    Write-Host ""

    Write-Host "2) Web App ($WebAppId):" -ForegroundColor Cyan
    Write-Host "   $(Get-ConsentUrl -AppId $WebAppId)" -ForegroundColor White
    Write-Host ""

    if ($E2EAppId) {
        Write-Host "3) E2E App ($E2EAppId):" -ForegroundColor Cyan
        Write-Host "   $(Get-ConsentUrl -AppId $E2EAppId)" -ForegroundColor White
        Write-Host ""
    }

    Write-Host "Tip: Re-run this script with -AutoConsent to grant consent programmatically" -ForegroundColor DarkYellow
    Write-Host "     (requires DelegatedPermissionGrant.ReadWrite.All and AppRoleAssignment.ReadWrite.All)." -ForegroundColor DarkYellow
    Write-Host ""
}
