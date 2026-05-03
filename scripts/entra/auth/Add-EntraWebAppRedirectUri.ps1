# ============================================================================
# Script Name:   Add-EntraWebAppRedirectUri.ps1
# Description:   Idempotently adds a redirect URI to an existing Entra Web
#                App Registration. Does nothing if the URI is already present.
# -----------------------------------------------------------------------------
# Example:
#   pwsh -File ./Add-EntraWebAppRedirectUri.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -AppRegistrationName "myproduct-web-dev-001" `
#       -RedirectUri "https://localhost:5001/signin-oidc"
# ============================================================================
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$AppRegistrationName,
    [Parameter(Mandatory)][string]$RedirectUri
)

$modules = @("Az.Accounts", "Microsoft.Graph.Applications")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Install-Module $module -Scope CurrentUser -Force
    }
}
Import-Module Az.Accounts                  -ErrorAction Stop
Import-Module Microsoft.Graph.Applications -ErrorAction Stop

$azContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
    Connect-AzAccount -Tenant $TenantId | Out-Null
}

$mgContext = $null
try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}
if (-not $mgContext -or $mgContext.TenantId -ne $TenantId) {
    Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All" -NoWelcome | Out-Null
}

$app = Get-MgApplication -Filter "displayName eq '$AppRegistrationName'" -ErrorAction Stop
if (-not $app) {
    Write-Error "FATAL: App registration '$AppRegistrationName' not found."
    exit 1
}

$existing = $app.Web.RedirectUris
if ($existing -contains $RedirectUri) {
    Write-Host "Redirect URI already present — no change needed: $RedirectUri"
    exit 0
}

$updated = @($existing) + $RedirectUri
Update-MgApplication -ApplicationId $app.Id -BodyParameter @{
    web = @{ redirectUris = $updated }
}
Write-Host "Added redirect URI: $RedirectUri"
Write-Host "All redirect URIs for '$AppRegistrationName':"
($updated) | ForEach-Object { Write-Host "  $_" }
