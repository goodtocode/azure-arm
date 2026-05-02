# ============================================================================
# Script Name:   New-EntraApiApp.ps1
# Description:   Creates or updates the Entra App Registration for an API
#                (resource server). Configures OAuth2 delegated scopes, app
#                roles for both users and machines, and Microsoft Graph
#                User.Read delegated permission. Optionally writes .NET
#                user-secrets to the target project.
# -----------------------------------------------------------------------------
# OAuth Role:    Resource server — audience for delegated (Web) and
#                application (E2E / CI) tokens.
# Flows:         Bearer token validation only; no interactive sign-in.
# -----------------------------------------------------------------------------
# Example CLI Usage (standalone):
#   pwsh -File ./New-EntraApiApp.ps1 `
#       -EntraInstanceUrl "https://your-tenant.ciamlogin.com" `
#       -TenantId "<your-tenant-id>" `
#       -AppRegistrationName "myproduct-api-dev-001" `
#       -ProjectPath "../../src/Presentation.WebApi"
#
# Example (called from orchestrator — prereqs/auth already established):
#   $api = & "$PSScriptRoot\auth\New-EntraApiApp.ps1" `
#       -EntraInstanceUrl $EntraInstanceUrl -TenantId $TenantId `
#       -AppRegistrationName $ApiAppRegistrationName `
#       -ProjectPath $ApiProjectPath
# -----------------------------------------------------------------------------
# Returns:
#   [PSCustomObject] @{
#       AppId             = <string>
#       ObjectId          = <string>
#       ServicePrincipalId = <string>
#       Type              = "Api"
#       Created           = <bool>
#       Capabilities      = @("delegated","appRoles","application")
#   }
# ============================================================================
param(
    [Parameter(Mandatory)][string]$EntraInstanceUrl,
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$AppRegistrationName,
    [string]$ProjectPath = ""
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
        [string]$ObjectId     = $null,
        [int]$MaxRetries      = 10,
        [int]$DelaySeconds    = 2
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

# ── Create or retrieve API app registration ───────────────────────────────────
Write-Host ""
Write-Host "=== API App Registration: $AppRegistrationName ==="
$apiApp = Get-MgApplication -Filter "displayName eq '$AppRegistrationName'" -ErrorAction SilentlyContinue
$created = $false

if (-not $apiApp) {
    Write-Host "Not found. Creating API app registration..."
    try {
        $apiApp = New-MgApplication -DisplayName $AppRegistrationName -SignInAudience AzureADMyOrg
    }
    catch {
        Write-Error "FATAL: Failed to create API app registration. $_"
        exit 1
    }
    if (-not $apiApp -or -not $apiApp.AppId) {
        Write-Error "FATAL: API app registration was not created."
        exit 1
    }
    $created = $true
    Write-Host "Created API app: $($apiApp.AppId)"

    # ── Identifier URI ───────────────────────────────────────────────────────
    $identifierUri = "api://$($apiApp.AppId)"
    Update-MgApplication -ApplicationId $apiApp.Id -IdentifierUris @($identifierUri)
    Write-Host "Set IdentifierUri: $identifierUri"

    # ── OAuth2 delegated permission scopes ───────────────────────────────────
    $customScopes = @(
        @{
            Id                        = [guid]::NewGuid()
            AdminConsentDisplayName   = "Access as user"
            AdminConsentDescription   = "Allows the app to act on behalf of the signed-in user (OBO flow)."
            UserConsentDisplayName    = "Access as you"
            UserConsentDescription    = "Allows the app to act on your behalf."
            IsEnabled                 = $true
            Type                      = "User"
            Value                     = "access_as_user"
        },
        @{
            Id                        = [guid]::NewGuid()
            AdminConsentDisplayName   = "Read assets"
            AdminConsentDescription   = "Allows the app to view asset data."
            UserConsentDisplayName    = "Read your assets"
            UserConsentDescription    = "Allows the app to view your assets."
            IsEnabled                 = $true
            Type                      = "User"
            Value                     = "assets.read"
        },
        @{
            Id                        = [guid]::NewGuid()
            AdminConsentDisplayName   = "Edit assets"
            AdminConsentDescription   = "Allows the app to create or update asset data."
            UserConsentDisplayName    = "Edit your assets"
            UserConsentDescription    = "Allows the app to create or update your assets."
            IsEnabled                 = $true
            Type                      = "User"
            Value                     = "assets.edit"
        },
        @{
            Id                        = [guid]::NewGuid()
            AdminConsentDisplayName   = "Delete assets"
            AdminConsentDescription   = "Allows the app to delete asset data."
            UserConsentDisplayName    = "Delete your assets"
            UserConsentDescription    = "Allows the app to delete your assets."
            IsEnabled                 = $true
            Type                      = "User"
            Value                     = "assets.delete"
        }
    )
    Update-MgApplication -ApplicationId $apiApp.Id -Api @{ OAuth2PermissionScopes = $customScopes }
    Write-Host "Added OAuth2 delegated permission scopes."

    # ── App roles — User AND Application member types ────────────────────────
    # AllowedMemberTypes includes "Application" so E2E / CI apps can be assigned
    # the Asset.Automation role without accidentally receiving user-scoped roles.
    $appRoles = @(
        @{
            Id                 = [guid]::NewGuid()
            AllowedMemberTypes = @("User")
            Description        = "Can view assets only."
            DisplayName        = "Asset Viewer"
            IsEnabled          = $true
            Value              = "AssetViewer"
        },
        @{
            Id                 = [guid]::NewGuid()
            AllowedMemberTypes = @("User")
            Description        = "Can view and edit assets."
            DisplayName        = "Asset Editor"
            IsEnabled          = $true
            Value              = "AssetEditor"
        },
        @{
            Id                 = [guid]::NewGuid()
            AllowedMemberTypes = @("User")
            Description        = "Can view, edit, and delete assets."
            DisplayName        = "Asset Admin"
            IsEnabled          = $true
            Value              = "AssetAdmin"
        },
        @{
            Id                 = [guid]::NewGuid()
            AllowedMemberTypes = @("Application")
            Description        = "Machine-level automation access for CI/CD and E2E testing."
            DisplayName        = "Asset Automation"
            IsEnabled          = $true
            Value              = "Asset.Automation"
        }
    )
    Update-MgApplication -ApplicationId $apiApp.Id -AppRoles $appRoles
    Write-Host "Added app roles (User roles + Application role for machine access)."

    $apiApp = Wait-ForApplicationPropagation -AppId $apiApp.AppId -ObjectId $apiApp.Id
}
else {
    Write-Host "API app registration already exists: $($apiApp.AppId)"
}

# ── Microsoft Graph User.Read delegated permission ────────────────────────────
Write-Host "Configuring Microsoft Graph User.Read delegated permission..."
$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
if (-not $msGraphSp) {
    Write-Error "FATAL: Microsoft Graph service principal not found."
    exit 1
}
$userReadPerm = $msGraphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq "User.Read" }
if (-not $userReadPerm) {
    Write-Error "FATAL: Microsoft Graph User.Read permission scope not found."
    exit 1
}
Update-MgApplication -ApplicationId $apiApp.Id -RequiredResourceAccess @(
    @{
        ResourceAppId  = $msGraphSp.AppId
        ResourceAccess = @(@{ Id = $userReadPerm.Id; Type = "Scope" })
    }
)
Write-Host "Configured Microsoft Graph User.Read."

# ── Ensure service principal exists ──────────────────────────────────────────
$apiApp = Wait-ForApplicationPropagation -AppId $apiApp.AppId
$apiSp  = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $apiApp.AppId } | Select-Object -First 1
if (-not $apiSp) {
    Write-Host "Creating service principal for API app..."
    $apiSp = New-MgServicePrincipal -AppId $apiApp.AppId
    Start-Sleep -Seconds 5
}

# ── .NET user-secrets ─────────────────────────────────────────────────────────
Set-ProjectUserSecrets -ProjectPath $ProjectPath -Secrets @{
    "EntraExternalId:Instance"          = $EntraInstanceUrl
    "EntraExternalId:TenantId"          = $TenantId
    "EntraExternalId:ClientId"          = $apiApp.AppId
    "EntraExternalId:ValidateAuthority" = "true"
}

Write-Host "API app registration complete: $AppRegistrationName ($($apiApp.AppId))"

# ── Normalized return contract ─────────────────────────────────────────────────
return [PSCustomObject]@{
    AppId              = $apiApp.AppId
    ObjectId           = $apiApp.Id
    ServicePrincipalId = if ($apiSp) { $apiSp.Id } else { "" }
    Type               = "Api"
    Created            = $created
    Capabilities       = @("delegated", "appRoles", "application")
}
