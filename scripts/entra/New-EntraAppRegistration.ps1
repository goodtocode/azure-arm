<#
.SYNOPSIS
Creates or reconciles exactly one Entra app registration (Api, Web or E2E) and returns what the caller needs.

.DESCRIPTION
Idempotent and additive: finds the registration by display name, creates it when missing, and otherwise only adds what is missing (scopes, roles, claims, redirect URIs, permissions). It never deletes or narrows existing settings and fails when the display name is ambiguous.
It does not write .NET user-secrets. New-EntraSolution.ps1 does that from the returned object, so every type is configured the same way.
Api: resource server with an identifier URI, delegated scopes, app roles, access token version and access token claims.
Web: Auth Code + PKCE sign-in with redirect URIs, Microsoft Graph and API delegated permissions, and ID token claims.
E2E: client credentials identity with an application permission on the API and the matching role assignment.
A client secret is created only with -GenerateSecret, and only for a new registration or with -RotateSecret.

.EXAMPLE
# API (resource server):
pwsh -File ./New-EntraAppRegistration.ps1 -Type Api -TenantId "<your-tenant-id>" -AppRegistrationName "myproduct-api-dev-001"

.EXAMPLE
# Web app that calls the API, with a client secret:
pwsh -File ./New-EntraAppRegistration.ps1 -Type Web -TenantId "<your-tenant-id>" -AppRegistrationName "myproduct-web-dev-001" -ApiAppId "<api-app-client-id>" -RedirectUris "https://localhost:7175/signin-oidc" -LogoutUri "https://localhost:7175/signout-callback-oidc" -GenerateSecret -ProjectName "Presentation.Web"

.EXAMPLE
# E2E / CI identity that calls the API as an application:
pwsh -File ./New-EntraAppRegistration.ps1 -Type E2E -TenantId "<your-tenant-id>" -AppRegistrationName "myproduct-e2e-dev-001" -ApiAppId "<api-app-client-id>" -GenerateSecret -SecretMonths 12 -ProjectName "Tests.Endtoend"

.EXAMPLE
# Add an extra scope and claim to an existing API registration:
pwsh -File ./New-EntraAppRegistration.ps1 -Type Api -TenantId "<your-tenant-id>" -AppRegistrationName "myproduct-api-dev-001" -Scopes "access_as_user","assets.read","reports.read" -AccessTokenClaims "email","given_name","family_name","upn","ctry"

.OUTPUTS
[PSCustomObject] with AppId, ObjectId, ServicePrincipalId, Type, Created, IdentifierUri, Scopes, Roles, Secret ($null unless a secret was created), SecretDescription and Capabilities.

.NOTES
- Requires PowerShell modules Az.Accounts, Az.Resources, Microsoft.Graph.Applications.
- Defaults per type apply only to parameters you do not pass. Passing an empty array leaves that setting untouched.
- A returned Secret cannot be retrieved later; capture it or let New-EntraSolution.ps1 store it.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Api', 'Web', 'E2E')][string]$Type,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$AppRegistrationName,

    # Web and E2E: the API registration they call.
    [string]$ApiAppId,
    [string[]]$ApiScopes = @('access_as_user', 'assets.read', 'assets.edit', 'assets.delete'),
    [string]$ApiRole = 'Asset.Automation',

    # Api: what the resource server exposes.
    [string[]]$Scopes = @('access_as_user', 'assets.read', 'assets.edit', 'assets.delete'),
    [string[]]$UserRoles,
    [string[]]$ApplicationRoles,
    [ValidateSet(1, 2)][int]$AccessTokenVersion = 2,

    # Web: sign-in configuration.
    [string[]]$RedirectUris = @('https://localhost:7175/signin-oidc'),
    [string]$LogoutUri = 'https://localhost:7175/signout-callback-oidc',
    [string[]]$GraphPermissions = @('User.Read', 'email', 'profile'),

    # Claims added to tokens. Defaults depend on -Type.
    [string[]]$IdTokenClaims,
    [string[]]$AccessTokenClaims,

    # Secrets.
    [switch]$GenerateSecret,
    [switch]$RotateSecret,
    [int]$SecretMonths = 24,
    [string]$ProjectName = '',

    [switch]$SkipPrerequisites
)

$ErrorActionPreference = 'Stop'
$graphAppId = '00000003-0000-0000-c000-000000000000'

# ── Defaults that depend on -Type ─────────────────────────────────────────────
if (-not $PSBoundParameters.ContainsKey('UserRoles')) {
    $UserRoles = switch ($Type) {
        'Api' { @('AssetViewer', 'AssetEditor', 'AssetAdmin') }
        'Web' { @('Asset.Admin') }
        default { @() }
    }
}
if (-not $PSBoundParameters.ContainsKey('ApplicationRoles')) {
    $ApplicationRoles = if ($Type -eq 'Api') { @('Asset.Automation') } else { @() }
}
if (-not $PSBoundParameters.ContainsKey('IdTokenClaims')) {
    $IdTokenClaims = if ($Type -eq 'Web') { @('email', 'family_name', 'given_name', 'preferred_username', 'upn', 'ctry', 'ipaddr') } else { @() }
}
if (-not $PSBoundParameters.ContainsKey('AccessTokenClaims')) {
    $AccessTokenClaims = if ($Type -eq 'Api') { @('email', 'family_name', 'given_name', 'upn') } else { @() }
}

if ($Type -ne 'Api' -and [string]::IsNullOrWhiteSpace($ApiAppId)) {
    throw "-ApiAppId is required for -Type $Type."
}
if ($Type -eq 'Api' -and ($GenerateSecret -or $RotateSecret)) {
    Write-Warning "A resource server does not need a client secret; ignoring -GenerateSecret/-RotateSecret for -Type Api."
    $GenerateSecret = $false
    $RotateSecret = $false
}

# ── Prerequisites and sign-in ─────────────────────────────────────────────────
function Install-Prerequisites {
    foreach ($module in @('Az.Accounts', 'Az.Resources', 'Microsoft.Graph.Applications')) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing PowerShell module: $module"
            Install-Module $module -Scope CurrentUser -Force
        }
    }
    Import-Module Az.Accounts -ErrorAction Stop
    Import-Module Az.Resources -ErrorAction Stop
    Import-Module Microsoft.Graph.Applications -ErrorAction Stop
}

function Connect-EntraSession {
    param([string]$TenantId, [string[]]$RequiredScopes)

    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
        Write-Host "Logging into Azure tenant $TenantId..."
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }

    $mgContext = $null
    try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}
    $hasScopes = $mgContext -and $mgContext.Scopes -and (@($RequiredScopes | Where-Object { $_ -notin $mgContext.Scopes }).Count -eq 0)
    if (-not $mgContext -or $mgContext.TenantId -ne $TenantId -or -not $hasScopes) {
        Write-Host "Connecting to Microsoft Graph..."
        Connect-MgGraph -TenantId $TenantId -Scopes $RequiredScopes -NoWelcome | Out-Null
        $mgContext = Get-MgContext -ErrorAction Stop
        if (-not $mgContext -or $mgContext.TenantId -ne $TenantId) {
            throw "Microsoft Graph sign-in did not produce a context for tenant $TenantId."
        }
    }
}

if (-not $SkipPrerequisites) { Install-Prerequisites }
$graphScopesNeeded = @('Application.ReadWrite.All', 'Directory.ReadWrite.All')
if ($Type -eq 'E2E') { $graphScopesNeeded += 'AppRoleAssignment.ReadWrite.All' }
Connect-EntraSession -TenantId $TenantId -RequiredScopes $graphScopesNeeded

# ── Graph helpers ─────────────────────────────────────────────────────────────
function Get-AppByName([string]$Name) {
    $safe = $Name.Replace("'", "''")
    $apps = @(Get-MgApplication -Filter "displayName eq '$safe'" -All)
    if ($apps.Count -gt 1) { throw "Found $($apps.Count) app registrations named '$Name'. Rename or delete the duplicates first." }
    if ($apps.Count -eq 1) { return $apps[0] }
    return $null
}

function Get-AppByAppId([string]$AppId) {
    return Get-MgApplication -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Wait-ForApplication([string]$ObjectId) {
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 2
        $app = Get-MgApplication -ApplicationId $ObjectId -ErrorAction SilentlyContinue
        if ($app) { return $app }
    }
    throw "Application '$ObjectId' was not visible after waiting for propagation."
}

function Get-OrNew-ServicePrincipal([string]$AppId) {
    $sp = Get-MgServicePrincipal -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sp) {
        Write-Host "Creating service principal for $AppId..."
        $sp = New-MgServicePrincipal -AppId $AppId
        Start-Sleep -Seconds 5
    }
    return $sp
}

# Default consent text for the permissions and roles the template ships with.
$knownText = @{
    'access_as_user' = @('Access as user', 'Allows the app to act on behalf of the signed-in user.', 'Access as you', 'Allows the app to act on your behalf.')
    'assets.read'    = @('Read assets', 'Allows the app to view asset data.', 'Read your assets', 'Allows the app to view your assets.')
    'assets.edit'    = @('Edit assets', 'Allows the app to create or update asset data.', 'Edit your assets', 'Allows the app to create or update your assets.')
    'assets.delete'  = @('Delete assets', 'Allows the app to delete asset data.', 'Delete your assets', 'Allows the app to delete your assets.')
}
$knownRoles = @{
    'AssetViewer'      = @('Asset Viewer', 'Can view assets only.')
    'AssetEditor'      = @('Asset Editor', 'Can view and edit assets.')
    'AssetAdmin'       = @('Asset Admin', 'Can view, edit, and delete assets.')
    'Asset.Admin'      = @('Multi-tenant Admins', 'Administrators with ability to manage all tenant settings.')
    'Asset.Automation' = @('Asset Automation', 'Machine-level automation access for CI/CD and E2E testing.')
}

function ConvertTo-ScopeSpec($s) {
    return @{
        Id = $s.Id; Value = $s.Value; Type = $s.Type; IsEnabled = $s.IsEnabled
        AdminConsentDisplayName = $s.AdminConsentDisplayName; AdminConsentDescription = $s.AdminConsentDescription
        UserConsentDisplayName = $s.UserConsentDisplayName; UserConsentDescription = $s.UserConsentDescription
    }
}

function New-ScopeSpec([string]$Value) {
    $t = $knownText[$Value]
    if (-not $t) { $t = @("Use $Value", "Allows the app to use the '$Value' permission on behalf of the signed-in user.", "Use $Value", "Allows the app to use the '$Value' permission on your behalf.") }
    return @{
        Id = [guid]::NewGuid(); Value = $Value; Type = 'User'; IsEnabled = $true
        AdminConsentDisplayName = $t[0]; AdminConsentDescription = $t[1]; UserConsentDisplayName = $t[2]; UserConsentDescription = $t[3]
    }
}

function ConvertTo-RoleSpec($r) {
    return @{ Id = $r.Id; Value = $r.Value; DisplayName = $r.DisplayName; Description = $r.Description; IsEnabled = $r.IsEnabled; AllowedMemberTypes = @($r.AllowedMemberTypes) }
}

function New-RoleSpec([string]$Value, [string]$MemberType) {
    $t = $knownRoles[$Value]
    if (-not $t) { $t = @($Value, "Grants the '$Value' role.") }
    return @{ Id = [guid]::NewGuid(); Value = $Value; DisplayName = $t[0]; Description = $t[1]; IsEnabled = $true; AllowedMemberTypes = @($MemberType) }
}

function ConvertTo-ClaimSpec($c) {
    $spec = @{ name = $c.Name }
    if ($c.Source) { $spec.source = $c.Source }
    if ($c.Essential) { $spec.essential = $c.Essential }
    if ($c.AdditionalProperties -and @($c.AdditionalProperties).Count -gt 0) { $spec.additionalProperties = @($c.AdditionalProperties) }
    return $spec
}

# Adds missing claims to the token types we manage and keeps every existing claim.
function Get-MergedOptionalClaims($app, [string[]]$IdClaims, [string[]]$AccessClaims) {
    $existing = $app.OptionalClaims
    $merged = @{
        idToken     = @(@($existing.IdToken) | Where-Object { $_ } | ForEach-Object { ConvertTo-ClaimSpec $_ })
        accessToken = @(@($existing.AccessToken) | Where-Object { $_ } | ForEach-Object { ConvertTo-ClaimSpec $_ })
        saml2Token  = @(@($existing.Saml2Token) | Where-Object { $_ } | ForEach-Object { ConvertTo-ClaimSpec $_ })
    }
    $changed = $false
    foreach ($pair in @(@('idToken', $IdClaims), @('accessToken', $AccessClaims))) {
        $kind = $pair[0]
        foreach ($name in @($pair[1])) {
            if ($name -and -not ($merged[$kind] | Where-Object { $_.name -eq $name })) {
                $merged[$kind] += @{ name = $name }
                $changed = $true
            }
        }
    }
    if (-not $changed) { return $null }
    return $merged
}

# Adds resource permissions and keeps everything already granted to other resources.
function Get-MergedResourceAccess($app, [string]$ResourceAppId, [object[]]$Wanted) {
    $byResource = [ordered]@{}
    foreach ($r in @($app.RequiredResourceAccess | Where-Object { $_ })) {
        $byResource[$r.ResourceAppId] = @($r.ResourceAccess | ForEach-Object { @{ Id = $_.Id; Type = $_.Type } })
    }
    if (-not $byResource.Contains($ResourceAppId)) { $byResource[$ResourceAppId] = @() }
    $changed = $false
    foreach ($w in $Wanted) {
        if (-not ($byResource[$ResourceAppId] | Where-Object { $_.Id -eq $w.Id })) {
            $byResource[$ResourceAppId] += @{ Id = $w.Id; Type = $w.Type }
            $changed = $true
        }
    }
    if (-not $changed) { return $null }
    return @($byResource.Keys | ForEach-Object { @{ ResourceAppId = $_; ResourceAccess = @($byResource[$_]) } })
}

# ── Resolve the API this registration depends on ──────────────────────────────
$apiReg = $null
if ($Type -ne 'Api') {
    $apiReg = Get-AppByAppId $ApiAppId
    if (-not $apiReg) { throw "API app registration '$ApiAppId' not found. Create it first with -Type Api." }
}

# ── Create or find the registration ───────────────────────────────────────────
Write-Host ""
Write-Host "=== $Type app registration: $AppRegistrationName ==="
$app = Get-AppByName $AppRegistrationName
$created = $false
if (-not $app) {
    Write-Host "Not found. Creating..."
    $app = New-MgApplication -DisplayName $AppRegistrationName -SignInAudience AzureADMyOrg
    if (-not $app -or -not $app.AppId) { throw "App registration '$AppRegistrationName' was not created." }
    $created = $true
    $app = Wait-ForApplication $app.Id
    Write-Host "Created: $($app.AppId)"
}
else {
    Write-Host "Already exists: $($app.AppId). Adding anything missing."
}

# ── Type-specific configuration ───────────────────────────────────────────────
$identifierUri = ''
if ($Type -eq 'Api') {
    $identifierUri = "api://$($app.AppId)"
    if (@($app.IdentifierUris).Count -eq 0) {
        Update-MgApplication -ApplicationId $app.Id -IdentifierUris @($identifierUri)
        Write-Host "Set identifier URI: $identifierUri"
    }
    else {
        $identifierUri = @($app.IdentifierUris)[0]
    }

    $apiUpdate = @{}
    $existingScopes = @(@($app.Api.Oauth2PermissionScopes) | Where-Object { $_ } | ForEach-Object { ConvertTo-ScopeSpec $_ })
    $existingScopeValues = @($existingScopes | ForEach-Object { $_.Value })
    $newScopes = @($Scopes | Where-Object { $_ -and $_ -notin $existingScopeValues } | ForEach-Object { New-ScopeSpec $_ })
    if ($newScopes.Count -gt 0) {
        $apiUpdate.OAuth2PermissionScopes = @($existingScopes + $newScopes)
        Write-Host "Adding scopes: $(($newScopes | ForEach-Object { $_.Value }) -join ', ')"
    }
    if ($app.Api.RequestedAccessTokenVersion -ne $AccessTokenVersion) {
        $apiUpdate.RequestedAccessTokenVersion = $AccessTokenVersion
        Write-Host "Setting access token version to $AccessTokenVersion."
    }
    if ($apiUpdate.Count -gt 0) { Update-MgApplication -ApplicationId $app.Id -Api $apiUpdate }
}

if ($Type -in 'Api', 'Web') {
    $existingRoles = @(@($app.AppRoles) | Where-Object { $_ } | ForEach-Object { ConvertTo-RoleSpec $_ })
    $existingRoleValues = @($existingRoles | ForEach-Object { $_.Value })
    $newRoles = @()
    $newRoles += @($UserRoles | Where-Object { $_ -and $_ -notin $existingRoleValues } | ForEach-Object { New-RoleSpec $_ 'User' })
    $newRoles += @($ApplicationRoles | Where-Object { $_ -and $_ -notin $existingRoleValues } | ForEach-Object { New-RoleSpec $_ 'Application' })
    if ($newRoles.Count -gt 0) {
        Update-MgApplication -ApplicationId $app.Id -AppRoles @($existingRoles + $newRoles)
        Write-Host "Adding app roles: $(($newRoles | ForEach-Object { $_.Value }) -join ', ')"
    }
}

if ($Type -eq 'Web') {
    $webUpdate = @{}
    $existingUris = @($app.Web.RedirectUris)
    $missingUris = @($RedirectUris | Where-Object { $_ -and $_ -notin $existingUris })
    if ($missingUris.Count -gt 0) {
        $webUpdate.RedirectUris = @($existingUris + $missingUris)
        Write-Host "Adding redirect URIs: $($missingUris -join ', ')"
    }
    if ($LogoutUri -and [string]::IsNullOrWhiteSpace($app.Web.LogoutUrl)) { $webUpdate.LogoutUrl = $LogoutUri }
    if ($created) {
        # Auth Code + PKCE: implicit grant stays off, per Microsoft.Identity.Web defaults.
        $webUpdate.ImplicitGrantSettings = @{ EnableIdTokenIssuance = $false; EnableAccessTokenIssuance = $false }
    }
    if ($webUpdate.Count -gt 0) { Update-MgApplication -ApplicationId $app.Id -Web $webUpdate }

    $graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'" -ErrorAction Stop | Select-Object -First 1
    $graphWanted = foreach ($perm in $GraphPermissions) {
        $s = $graphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm }
        if (-not $s) { throw "Microsoft Graph permission '$perm' not found." }
        @{ Id = $s.Id; Type = 'Scope' }
    }
    $merged = Get-MergedResourceAccess $app $graphAppId @($graphWanted)
    if ($merged) { Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess $merged; $app = Wait-ForApplication $app.Id }

    $apiWanted = foreach ($name in $ApiScopes) {
        $s = $apiReg.Api.Oauth2PermissionScopes | Where-Object { $_.Value -eq $name }
        if (-not $s) { throw "API scope '$name' not found on '$ApiAppId'. Add it to the API registration first." }
        @{ Id = $s.Id; Type = 'Scope' }
    }
    $merged = Get-MergedResourceAccess $app $ApiAppId @($apiWanted)
    if ($merged) { Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess $merged; $app = Wait-ForApplication $app.Id }
}

if ($Type -eq 'E2E') {
    $role = $apiReg.AppRoles | Where-Object { $_.Value -eq $ApiRole -and $_.AllowedMemberTypes -contains 'Application' } | Select-Object -First 1
    if (-not $role) { throw "Application role '$ApiRole' not found on API '$ApiAppId'. Create the API with -ApplicationRoles '$ApiRole' first." }
    $merged = Get-MergedResourceAccess $app $ApiAppId @(@{ Id = $role.Id; Type = 'Role' })
    if ($merged) { Update-MgApplication -ApplicationId $app.Id -RequiredResourceAccess $merged; $app = Wait-ForApplication $app.Id }
}

if ($IdTokenClaims.Count -gt 0 -or $AccessTokenClaims.Count -gt 0) {
    $claims = Get-MergedOptionalClaims $app $IdTokenClaims $AccessTokenClaims
    if ($claims) {
        Update-MgApplication -ApplicationId $app.Id -OptionalClaims $claims
        Write-Host "Updated optional claims."
    }
}

# ── Service principal and E2E role assignment ─────────────────────────────────
$app = Wait-ForApplication $app.Id
$sp = Get-OrNew-ServicePrincipal $app.AppId

if ($Type -eq 'E2E') {
    $apiSp = Get-OrNew-ServicePrincipal $ApiAppId
    $assigned = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.AppRoleId -eq $role.Id -and $_.ResourceId -eq $apiSp.Id }
    if (-not $assigned) {
        Write-Host "Granting '$ApiRole' to the E2E service principal..."
        New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -PrincipalId $sp.Id -ResourceId $apiSp.Id -AppRoleId $role.Id | Out-Null
    }
}

# ── Client secret ─────────────────────────────────────────────────────────────
$secret = $null
$secretDescription = $null
if ($GenerateSecret) {
    if ($created -or $RotateSecret) {
        $leaf = if ([string]::IsNullOrWhiteSpace($ProjectName)) { 'no-project' } else { $ProjectName }
        $secretDescription = "$AppRegistrationName | $leaf | created $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm'))Z by $([Environment]::UserName)@$([Environment]::MachineName)"
        $secretObj = Add-MgApplicationPassword -ApplicationId $app.Id -PasswordCredential @{ DisplayName = $secretDescription; EndDateTime = (Get-Date).AddMonths($SecretMonths) }
        if (-not $secretObj -or -not $secretObj.SecretText) { throw "The client secret was not created for '$AppRegistrationName'." }
        $secret = $secretObj.SecretText
        Write-Host "Created client secret: $secretDescription"
    }
    else {
        Write-Host "Skipping secret for existing registration. Use -RotateSecret to add another credential."
    }
}

Write-Host "$Type app registration complete: $AppRegistrationName ($($app.AppId))"

$capabilities = switch ($Type) {
    'Api' { @('delegated', 'appRoles', 'application') }
    'Web' { @('delegated') }
    'E2E' { @('application') }
}

return [PSCustomObject]@{
    AppId              = $app.AppId
    ObjectId           = $app.Id
    ServicePrincipalId = $sp.Id
    Type               = $Type
    Created            = $created
    IdentifierUri      = $identifierUri
    Scopes             = if ($Type -eq 'Api') { @($Scopes) } else { @() }
    Roles              = @($UserRoles) + @($ApplicationRoles)
    Secret             = $secret
    SecretDescription  = $secretDescription
    Capabilities       = $capabilities
}
