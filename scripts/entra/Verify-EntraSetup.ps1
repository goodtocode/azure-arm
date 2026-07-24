# ============================================================================
# Script Name:   Verify-EntraSetup.ps1
# Description:   Verifies common Entra setup prerequisites for local .NET Web -> API
#                delegated auth flows (EEID/AAD), including redirect URIs, exposed
#                API scope, required API permission wiring, and consent grants.
# -----------------------------------------------------------------------------
# Example:
#   pwsh -File ./.azure/scripts/entra/Verify-EntraSetup.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -WebAppRegistrationName "myproduct-web-dev-001" `
#       -ApiAppRegistrationName "myproduct-api-dev-001"
# ============================================================================

param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$WebAppRegistrationName,
    [Parameter(Mandatory)][string]$ApiAppRegistrationName,
    [string]$ExpectedRedirectUri = "https://localhost:6195/signin-oidc",
    [string]$ExpectedLogoutUri = "https://localhost:6195/signout-callback-oidc",
    [string]$RequiredApiScope = "access_as_user"
)

$failedChecks = New-Object System.Collections.Generic.List[string]
$warningChecks = New-Object System.Collections.Generic.List[string]

function Add-CheckResult {
    param(
        [Parameter(Mandatory)][bool]$Passed,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Details,
        [switch]$Warning
    )

    if ($Passed) {
        Write-Host "PASS: $Name" -ForegroundColor Green
        Write-Host "      $Details"
        return
    }

    if ($Warning) {
        Write-Host "WARN: $Name" -ForegroundColor Yellow
        Write-Host "      $Details"
        $warningChecks.Add($Name) | Out-Null
        return
    }

    Write-Host "FAIL: $Name" -ForegroundColor Red
    Write-Host "      $Details"
    $failedChecks.Add($Name) | Out-Null
}

function Install-Prerequisites {
    $modules = @("Az.Accounts", "Microsoft.Graph.Applications")
    foreach ($module in $modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing PowerShell module: $module"
            Install-Module $module -Scope CurrentUser -Force
        }
    }

    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
}

function New-Auth {
    param([string]$TenantId)

    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }

    $mgContext = $null
    try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}
    if (-not $mgContext -or $mgContext.TenantId -ne $TenantId -or -not $mgContext.Account) {
        Connect-MgGraph -TenantId $TenantId -Scopes "Application.Read.All", "Directory.Read.All", "DelegatedPermissionGrant.Read.All" -NoWelcome | Out-Null
    }
}

function Get-ConsentGrantsForWebToApi {
    param(
        [Parameter(Mandatory)][string]$WebServicePrincipalId,
        [Parameter(Mandatory)][string]$ApiServicePrincipalId
    )

    $cmdGlobal = Get-Command -Name Get-MgOauth2PermissionGrant -ErrorAction SilentlyContinue
    if ($cmdGlobal) {
        return Get-MgOauth2PermissionGrant -Filter "clientId eq '$WebServicePrincipalId' and resourceId eq '$ApiServicePrincipalId'" -All -ErrorAction SilentlyContinue
    }

    $cmdBySp = Get-Command -Name Get-MgServicePrincipalOauth2PermissionGrant -ErrorAction SilentlyContinue
    if ($cmdBySp) {
        return Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $WebServicePrincipalId -All -ErrorAction SilentlyContinue |
            Where-Object { $_.ResourceId -eq $ApiServicePrincipalId }
    }

    return $null
}

Install-Prerequisites
New-Auth -TenantId $TenantId

Write-Host ""
Write-Host "=== Verifying Entra setup for local Web -> API delegated auth ===" -ForegroundColor Cyan
Write-Host "TenantId: $TenantId"
Write-Host "Web App Registration: $WebAppRegistrationName"
Write-Host "API App Registration: $ApiAppRegistrationName"
Write-Host "Expected Redirect URI: $ExpectedRedirectUri"
Write-Host "Expected Logout URI:  $ExpectedLogoutUri"
Write-Host "Required API Scope:   $RequiredApiScope"

$webApp = Get-MgApplication -Filter "displayName eq '$WebAppRegistrationName'" -ErrorAction SilentlyContinue
$apiApp = Get-MgApplication -Filter "displayName eq '$ApiAppRegistrationName'" -ErrorAction SilentlyContinue

Add-CheckResult -Passed:([bool]$webApp) -Name "Web app registration exists" -Details "DisplayName '$WebAppRegistrationName'"
Add-CheckResult -Passed:([bool]$apiApp) -Name "API app registration exists" -Details "DisplayName '$ApiAppRegistrationName'"

if (-not $webApp -or -not $apiApp) {
    Write-Host ""
    Write-Host "Verification stopped because required app registrations were not found." -ForegroundColor Red
    exit 1
}

$webApp = $webApp | Select-Object -First 1
$apiApp = $apiApp | Select-Object -First 1

$apiSp = Get-MgServicePrincipal -Filter "appId eq '$($apiApp.AppId)'" -ErrorAction SilentlyContinue | Select-Object -First 1
$webSp = Get-MgServicePrincipal -Filter "appId eq '$($webApp.AppId)'" -ErrorAction SilentlyContinue | Select-Object -First 1

Add-CheckResult -Passed:([bool]$webSp) -Name "Web service principal exists" -Details "appId $($webApp.AppId)"
Add-CheckResult -Passed:([bool]$apiSp) -Name "API service principal exists" -Details "appId $($apiApp.AppId)"

$redirectUris = @()
if ($webApp.Web -and $webApp.Web.RedirectUris) {
    $redirectUris = @($webApp.Web.RedirectUris)
}

$logoutUri = if ($webApp.Web) { $webApp.Web.LogoutUrl } else { $null }

Add-CheckResult -Passed:($redirectUris -contains $ExpectedRedirectUri) -Name "Web redirect URI configured" -Details "Expected '$ExpectedRedirectUri'"
Add-CheckResult -Passed:($logoutUri -eq $ExpectedLogoutUri) -Name "Web logout URI configured" -Details "Expected '$ExpectedLogoutUri', current '$logoutUri'"

$apiScope = $null
if ($apiApp.Api -and $apiApp.Api.Oauth2PermissionScopes) {
    $apiScope = $apiApp.Api.Oauth2PermissionScopes | Where-Object { $_.Value -eq $RequiredApiScope -and $_.IsEnabled } | Select-Object -First 1
}

Add-CheckResult -Passed:([bool]$apiScope) -Name "API exposes enabled delegated scope" -Details "Expected scope '$RequiredApiScope'"

$webRequestsApiScope = $false
$requiredAccessEntry = $webApp.RequiredResourceAccess | Where-Object { $_.ResourceAppId -eq $apiApp.AppId } | Select-Object -First 1
if ($requiredAccessEntry -and $apiScope) {
    $webRequestsApiScope = @($requiredAccessEntry.ResourceAccess | Where-Object { $_.Type -eq "Scope" -and $_.Id -eq $apiScope.Id }).Count -gt 0
}

Add-CheckResult -Passed:$webRequestsApiScope -Name "Web app requests API delegated scope" -Details "Web requiredResourceAccess includes '$RequiredApiScope' from API app"

$scopeGranted = $false
$consentCheckPerformed = $false
if ($webSp -and $apiSp) {
    $grants = Get-ConsentGrantsForWebToApi -WebServicePrincipalId $webSp.Id -ApiServicePrincipalId $apiSp.Id
    if ($null -ne $grants) {
        $consentCheckPerformed = $true
        if ($grants) {
            $scopeGranted = @(
                $grants | Where-Object {
                    $_.Scope -and (($_.Scope -split ' ') -contains $RequiredApiScope)
                }
            ).Count -gt 0
        }
    }
}

if ($consentCheckPerformed) {
    Add-CheckResult -Passed:$scopeGranted -Name "Consent grant exists for Web -> API scope" -Details "Grant contains scope '$RequiredApiScope'"
}
else {
    Add-CheckResult -Passed:$false -Name "Consent grant cmdlet availability" -Details "Could not query OAuth2 permission grants. Ensure Microsoft Graph PowerShell is updated and includes grant cmdlets." -Warning
}

if ($webSp) {
    Add-CheckResult -Passed:(-not $webSp.AppRoleAssignmentRequired) -Name "Web enterprise app assignment required" -Details "AppRoleAssignmentRequired=$($webSp.AppRoleAssignmentRequired). If True, ensure your user is assigned." -Warning
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
if ($failedChecks.Count -eq 0) {
    Write-Host "Verification PASSED with no blocking failures." -ForegroundColor Green
}
else {
    Write-Host "Verification FAILED with $($failedChecks.Count) blocking issue(s)." -ForegroundColor Red
    foreach ($name in $failedChecks) {
        Write-Host "  - $name" -ForegroundColor Red
    }
}

if ($warningChecks.Count -gt 0) {
    Write-Host "Warnings: $($warningChecks.Count)" -ForegroundColor Yellow
    foreach ($name in $warningChecks) {
        Write-Host "  - $name" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Web app consent blade (grant admin consent if needed):" -ForegroundColor Cyan
Write-Host "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Permissions/appId/$($webApp.AppId)/isMSAApp~/false" -ForegroundColor Cyan

if ($failedChecks.Count -gt 0) {
    exit 1
}

exit 0
