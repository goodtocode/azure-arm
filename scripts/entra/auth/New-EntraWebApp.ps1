# ============================================================================
# Script Name:   New-EntraWebApp.ps1
# Description:   Creates or updates the Entra App Registration for a Web App
#                (interactive user sign-in). Configures Auth Code + PKCE flow,
#                Microsoft Graph delegated permissions, and API scopes from the
#                resource server. Client secret created only when -GenerateSecrets
#                is specified. Optionally writes .NET user-secrets.
# -----------------------------------------------------------------------------
# OAuth Role:    Delegated — human, interactive user (Auth Code + PKCE).
# Microsoft.Identity.Web defaults: implicit grant OFF, PKCE ON.
# -----------------------------------------------------------------------------
# Example CLI Usage (standalone):
#   pwsh -File ./New-EntraWebApp.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<your-tenant-id>" `
#       -AppRegistrationName "myproduct-web-dev-001" `
#       -ApiAppId "<api-app-client-id>" `
#       -ProjectPath "../../src/Presentation.Blazor" `
#       -GenerateSecrets
#
# Example (called from orchestrator — prereqs/auth already established):
#   $web = & "$PSScriptRoot\auth\New-EntraWebApp.ps1" `
#       -EntraInstanceUrl $EntraInstanceUrl -TenantId $TenantId `
#       -AppRegistrationName $WebAppRegistrationName `
#       -ApiAppId $api.AppId `
#       -ProjectPath $WebProjectPath `
#       -GenerateSecrets:$GenerateSecrets
# -----------------------------------------------------------------------------
# Returns:
#   [PSCustomObject] @{
#       AppId              = <string>
#       ObjectId           = <string>
#       ServicePrincipalId = <string>
#       Type               = "Web"
#       Created            = <bool>
#       Capabilities       = @("delegated")
#       Secret             = <string|$null>   # $null unless -GenerateSecrets
#   }
# ============================================================================
param(
    [Parameter(Mandatory)][string]$EntraInstanceUrl,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$AppRegistrationName,
    [Parameter(Mandatory)][string]$ApiAppId,
    [string]$ProjectPath  = "",
    [string]$RedirectUri  = "https://localhost:7175/signin-oidc",
    [string]$LogoutUri    = "https://localhost:7175/signout-callback-oidc",
    [switch]$GenerateSecrets,
    [switch]$RotateSecret
)

# ── Shared helpers ────────────────────────────────────────────────────────────

function Install-Prerequisites {
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

    $requiredScopes = @("Application.ReadWrite.All", "Directory.ReadWrite.All")
    $mgContext = $null
    try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}

    $hasRequiredScopes = $false
    if ($mgContext -and $mgContext.Scopes) {
        $hasRequiredScopes = ($requiredScopes | Where-Object { $_ -notin $mgContext.Scopes }).Count -eq 0
    }

    if (-not $mgContext -or $mgContext.TenantId -ne $TenantId -or -not $hasRequiredScopes) {
        Write-Host "Connecting to Microsoft Graph..."
        try {
            Connect-MgGraph -TenantId $TenantId -Scopes $requiredScopes -NoWelcome | Out-Null
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

function Wait-ForApplicationPropagation {
    param(
        [string]$AppId,
        [string]$ObjectId   = $null,
        [int]$MaxRetries    = 10,
        [int]$DelaySeconds  = 2
    )
    $retryCount = 0
    $app        = $null
    do {
        Start-Sleep -Seconds $DelaySeconds
        if ($ObjectId) {
            $app = Get-MgApplication -ApplicationId $ObjectId -ErrorAction SilentlyContinue
        }
        if (-not $app -and $AppId) {
            $app = Get-MgApplication -Filter "appId eq '$AppId'" -ErrorAction SilentlyContinue
        }
        $retryCount++
    } while (-not $app -and $retryCount -lt $MaxRetries)

    if (-not $app) {
        Write-Error "FATAL: Application '$AppId' was not found after $MaxRetries retries. Exiting."
        exit 1
    }
    return $app
}

function Set-ProjectUserSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets)
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { return }
    $resolvedPath = Resolve-Path -Path $ProjectPath -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Warning "*** Project path '$ProjectPath' not found. Skipping dotnet user-secrets. ***"
        return
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
        return
    }

    Write-Host "Setting .NET user-secrets for project: $projectFile"
    dotnet user-secrets init --project "$projectFile" | Out-Null
    foreach ($key in $Secrets.Keys) {
        dotnet user-secrets set "$key" "$($Secrets[$key])" --project "$projectFile" | Out-Null
        Write-Host "  Set: $key"
    }
}

# ── Prerequisites & authentication ───────────────────────────────────────────
Install-Prerequisites
Connect-EntraSession -TenantId $TenantId

# ── Create or retrieve Web app registration ───────────────────────────────────
Write-Host ""
Write-Host "=== Web App Registration: $AppRegistrationName ==="
$webApp    = Get-MgApplication -Filter "displayName eq '$AppRegistrationName'" -ErrorAction SilentlyContinue
$created   = $false
$webSecret = $null

if (-not $webApp) {
    Write-Host "Not found. Creating Web app registration..."
    try {
        $webApp = New-MgApplication `
            -DisplayName    $AppRegistrationName `
            -SignInAudience AzureADMyOrg `
            -Web @{
                RedirectUris = @($RedirectUri)
                LogoutUrl    = $LogoutUri
            }
    }
    catch {
        Write-Error "FATAL: Failed to create Web app registration. $_"
        exit 1
    }
    if (-not $webApp -or -not $webApp.AppId) {
        Write-Error "FATAL: Web app registration was not created."
        exit 1
    }
    $created = $true
    Write-Host "Created Web app: $($webApp.AppId)"

    # Auth Code + PKCE — implicit grant OFF per Microsoft.Identity.Web defaults
    Update-MgApplication -ApplicationId $webApp.Id -Web @{
        ImplicitGrantSettings = @{
            EnableIdTokenIssuance     = $false
            EnableAccessTokenIssuance = $false
        }
    }
    Write-Host "Configured Auth Code + PKCE (implicit grant disabled)."

    # App role for admin consent grouping
    $webAppRoles = @(
        @{
            Id                 = [Guid]::NewGuid()
            AllowedMemberTypes = @("User")
            Description        = "Administrators with ability to manage all tenant settings."
            DisplayName        = "Multi-tenant Admins"
            IsEnabled          = $true
            Value              = "Asset.Admin"
        }
    )
    Update-MgApplication -ApplicationId $webApp.Id -AppRoles $webAppRoles
    Write-Host "Added Asset.Admin app role."

    # Optional claims (token enrichment for Microsoft.Identity.Web)
    $optionalClaims = @{
        idToken = @(
            @{ name = "email" },
            @{ name = "family_name" },
            @{ name = "given_name" },
            @{ name = "preferred_username" },
            @{ name = "upn" },
            @{ name = "ctry" },
            @{ name = "ipaddr" }
        )
    }
    Update-MgApplication -ApplicationId $webApp.Id -OptionalClaims $optionalClaims
    Write-Host "Added optional claims (email, family_name, given_name, preferred_username, upn, ctry, ipaddr)."

    $webApp = Wait-ForApplicationPropagation -AppId $webApp.AppId -ObjectId $webApp.Id
}
else {
    Write-Host "Web app registration already exists: $($webApp.AppId)"
}

# ── Client secret (gated behind -GenerateSecrets) ─────────────────────────────
if ($GenerateSecrets -and ($created -or $RotateSecret)) {
    $secretAction = if ($created) { "initial" } else { "rotation" }
    Write-Host "Generating client secret for Web app ($secretAction, expires in 2 years)..."
    try {
        $secretObj = Add-MgApplicationPassword `
            -ApplicationId      $webApp.Id `
            -PasswordCredential @{ EndDateTime = (Get-Date).AddYears(2) }
        $webSecret = $secretObj.SecretText
        Write-Host ""
        Write-Host "CLIENT SECRET (copy now — shown once):" -ForegroundColor Yellow
        Write-Host $webSecret -ForegroundColor Cyan
        Write-Host ""
    }
    catch {
        Write-Error "FATAL: Failed to create client secret. $_"
        exit 1
    }
}
elseif ($GenerateSecrets -and -not $created -and -not $RotateSecret) {
    Write-Host "Skipping secret generation for existing Web app (idempotent default)."
    Write-Host "Use -RotateSecret to intentionally create an additional credential." -ForegroundColor DarkYellow
}
else {
    Write-Host "Skipping secret generation (-GenerateSecrets not specified)."
}

# ── Microsoft Graph delegated permissions ─────────────────────────────────────
Write-Host "Configuring Microsoft Graph delegated permissions (User.Read, email, profile)..."
$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
if (-not $msGraphSp) {
    Write-Error "FATAL: Microsoft Graph service principal not found."
    exit 1
}
$delegatedPermNames = @("User.Read", "email", "profile")
$graphScopes        = @()
foreach ($perm in $delegatedPermNames) {
    $scope = $msGraphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm }
    if (-not $scope) {
        Write-Error "FATAL: Microsoft Graph permission '$perm' not found."
        exit 1
    }
    $graphScopes += @{ Id = $scope.Id; Type = "Scope" }
}

# ── API scopes from the resource server ──────────────────────────────────────
Write-Host "Configuring API delegated scopes from resource server ($ApiAppId)..."
$apiAppReg = Get-MgApplication -Filter "appId eq '$ApiAppId'" -ErrorAction SilentlyContinue
if (-not $apiAppReg) {
    Write-Error "FATAL: API app registration with AppId '$ApiAppId' not found. Run New-EntraApiApp.ps1 first."
    exit 1
}
$apiScopeNames = @("access_as_user", "assets.read", "assets.edit", "assets.delete")
$apiScopes     = @()
foreach ($scopeName in $apiScopeNames) {
    $scope = $apiAppReg.Api.Oauth2PermissionScopes | Where-Object { $_.Value -eq $scopeName }
    if (-not $scope) {
        Write-Error "FATAL: API scope '$scopeName' not found. Ensure New-EntraApiApp.ps1 ran successfully."
        exit 1
    }
    $apiScopes += @{ Id = $scope.Id; Type = "Scope" }
}

Update-MgApplication -ApplicationId $webApp.Id -RequiredResourceAccess @(
    @{ ResourceAppId = $msGraphSp.AppId; ResourceAccess = $graphScopes },
    @{ ResourceAppId = $ApiAppId;        ResourceAccess = $apiScopes }
)
Write-Host "Configured Graph and API delegated permissions."

# ── Ensure service principal exists ──────────────────────────────────────────
$webApp = Wait-ForApplicationPropagation -AppId $webApp.AppId
$webSp  = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $webApp.AppId } | Select-Object -First 1
if (-not $webSp) {
    Write-Host "Creating service principal for Web app..."
    $webSp = New-MgServicePrincipal -AppId $webApp.AppId
    Start-Sleep -Seconds 5
}

# ── .NET user-secrets ─────────────────────────────────────────────────────────
$userSecrets = @{
    "BackEndApi:ClientId"               = $ApiAppId
    "EntraExternalId:Instance"          = $EntraInstanceUrl
    "EntraExternalId:TenantId"          = $TenantId
    "EntraExternalId:ClientId"          = $webApp.AppId
    "EntraExternalId:ValidateAuthority" = "true"
}
if ($webSecret) {
    $userSecrets["EntraExternalId:ClientSecret"] = $webSecret
}
Set-ProjectUserSecrets -ProjectPath $ProjectPath -Secrets $userSecrets

Write-Host "Web app registration complete: $AppRegistrationName ($($webApp.AppId))"

# ── Normalized return contract ─────────────────────────────────────────────────
return [PSCustomObject]@{
    AppId              = $webApp.AppId
    ObjectId           = $webApp.Id
    ServicePrincipalId = if ($webSp) { $webSp.Id } else { "" }
    Type               = "Web"
    Created            = $created
    Capabilities       = @("delegated")
    Secret             = $webSecret   # $null unless -GenerateSecrets was set
}
