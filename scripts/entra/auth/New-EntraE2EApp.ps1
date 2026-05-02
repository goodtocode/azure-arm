# ============================================================================
# Script Name:   New-EntraE2EApp.ps1
# Description:   Creates or updates the Entra App Registration for automated
#                E2E testing or CI/CD pipelines (machine identity).
#                Uses Client Credentials flow — no user sign-in.
#                Assigns the Asset.Automation application role from the
#                resource server. Client secret created only when
#                -GenerateSecrets is specified.
# -----------------------------------------------------------------------------
# OAuth Role:    Application — machine / automation (Client Credentials).
# Audience:      CI pipelines, integration tests, background services.
# IMPORTANT:     Do NOT add this registration unless you need machine auth.
#                Use -IncludeE2E on the orchestrator to opt in explicitly.
# -----------------------------------------------------------------------------
# Example CLI Usage (standalone):
#   pwsh -File ./New-EntraE2EApp.ps1 `
#       -TenantId "<your-tenant-id>" `
#       -AppRegistrationName "myproduct-e2e-dev-001" `
#       -ApiAppId "<api-app-client-id>" `
#       -ProjectPath "../../tests/E2E" `
#       -GenerateSecrets
#
# Example (called from orchestrator):
#   $e2e = & "$PSScriptRoot\auth\New-EntraE2EApp.ps1" `
#       -TenantId $TenantId `
#       -AppRegistrationName $E2EAppRegistrationName `
#       -ApiAppId $api.AppId `
#       -ProjectPath $E2EProjectPath `
#       -GenerateSecrets:$GenerateSecrets
# -----------------------------------------------------------------------------
# Returns:
#   [PSCustomObject] @{
#       AppId              = <string>
#       ObjectId           = <string>
#       ServicePrincipalId = <string>
#       Type               = "E2E"
#       Created            = <bool>
#       Capabilities       = @("application")
#       Secret             = <string|$null>   # $null unless -GenerateSecrets
#   }
# ============================================================================
param(
    [Parameter(Mandatory)][string]$TenantId,
    [Parameter(Mandatory)][string]$AppRegistrationName,
    [Parameter(Mandatory)][string]$ApiAppId,
    [string]$ProjectPath = "",
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

    $requiredScopes = @("Application.ReadWrite.All", "Directory.ReadWrite.All", "AppRoleAssignment.ReadWrite.All")
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

# ── Resolve API app registration ──────────────────────────────────────────────
Write-Host "Resolving resource server app registration ($ApiAppId)..."
$apiAppReg = Get-MgApplication -Filter "appId eq '$ApiAppId'" -ErrorAction SilentlyContinue
if (-not $apiAppReg) {
    Write-Error "FATAL: API app registration with AppId '$ApiAppId' not found. Run New-EntraApiApp.ps1 first."
    exit 1
}
$apiSp = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $ApiAppId } | Select-Object -First 1
if (-not $apiSp) {
    Write-Error "FATAL: Service principal for API app '$ApiAppId' not found."
    exit 1
}
$automationRole = $apiSp.AppRoles | Where-Object { $_.Value -eq "Asset.Automation" -and $_.AllowedMemberTypes -contains "Application" }
if (-not $automationRole) {
    Write-Error "FATAL: 'Asset.Automation' application role not found on API app. Ensure New-EntraApiApp.ps1 ran successfully."
    exit 1
}

# ── Create or retrieve E2E app registration ───────────────────────────────────
Write-Host ""
Write-Host "=== E2E App Registration: $AppRegistrationName ==="
$e2eApp    = Get-MgApplication -Filter "displayName eq '$AppRegistrationName'" -ErrorAction SilentlyContinue
$created   = $false
$e2eSecret = $null

if (-not $e2eApp) {
    Write-Host "Not found. Creating E2E app registration..."
    try {
        # No Web/SPA redirects — client credentials does not use interactive flow
        $e2eApp = New-MgApplication -DisplayName $AppRegistrationName -SignInAudience AzureADMyOrg
    }
    catch {
        Write-Error "FATAL: Failed to create E2E app registration. $_"
        exit 1
    }
    if (-not $e2eApp -or -not $e2eApp.AppId) {
        Write-Error "FATAL: E2E app registration was not created."
        exit 1
    }
    $created = $true
    Write-Host "Created E2E app: $($e2eApp.AppId)"

    # Request the Asset.Automation application permission from the API
    Update-MgApplication -ApplicationId $e2eApp.Id -RequiredResourceAccess @(
        @{
            ResourceAppId  = $ApiAppId
            ResourceAccess = @(@{ Id = $automationRole.Id; Type = "Role" })
        }
    )
    Write-Host "Configured Asset.Automation application permission from resource server."

    $e2eApp = Wait-ForApplicationPropagation -AppId $e2eApp.AppId -ObjectId $e2eApp.Id
}
else {
    Write-Host "E2E app registration already exists: $($e2eApp.AppId)"
}

# ── Client secret (gated behind -GenerateSecrets) ─────────────────────────────
if ($GenerateSecrets -and ($created -or $RotateSecret)) {
    $secretAction = if ($created) { "initial" } else { "rotation" }
    Write-Host "Generating client secret for E2E app ($secretAction, expires in 1 year)..."
    try {
        $secretObj = Add-MgApplicationPassword `
            -ApplicationId      $e2eApp.Id `
            -PasswordCredential @{ EndDateTime = (Get-Date).AddYears(1) }
        $e2eSecret = $secretObj.SecretText
        Write-Host ""
        Write-Host "E2E CLIENT SECRET (copy now — shown once):" -ForegroundColor Yellow
        Write-Host $e2eSecret -ForegroundColor Cyan
        Write-Host "(Consider using a certificate for CI/CD production environments.)" -ForegroundColor DarkYellow
        Write-Host ""
    }
    catch {
        Write-Error "FATAL: Failed to create client secret for E2E app. $_"
        exit 1
    }
}
elseif ($GenerateSecrets -and -not $created -and -not $RotateSecret) {
    Write-Host "Skipping secret generation for existing E2E app (idempotent default)."
    Write-Host "Use -RotateSecret to intentionally create an additional credential." -ForegroundColor DarkYellow
}
else {
    Write-Host "Skipping secret generation (-GenerateSecrets not specified)."
}

# ── Ensure service principal exists ──────────────────────────────────────────
$e2eApp = Wait-ForApplicationPropagation -AppId $e2eApp.AppId
$e2eSp  = Get-MgServicePrincipal -All | Where-Object { $_.AppId -eq $e2eApp.AppId } | Select-Object -First 1
if (-not $e2eSp) {
    Write-Host "Creating service principal for E2E app..."
    $e2eSp = New-MgServicePrincipal -AppId $e2eApp.AppId
    Start-Sleep -Seconds 5
}

# ── Grant application role assignment (idempotent) ────────────────────────────
# This assigns Asset.Automation to the E2E service principal on the API SP.
if ($e2eSp) {
    $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $e2eSp.Id -ErrorAction SilentlyContinue |
        Where-Object { $_.AppRoleId -eq $automationRole.Id -and $_.ResourceId -eq $apiSp.Id }

    if (-not $existingAssignment) {
        Write-Host "Granting Asset.Automation role to E2E service principal..."
        New-MgServicePrincipalAppRoleAssignment `
            -ServicePrincipalId $e2eSp.Id `
            -PrincipalId        $e2eSp.Id `
            -ResourceId         $apiSp.Id `
            -AppRoleId          $automationRole.Id | Out-Null
        Write-Host "Role assignment complete."
    }
    else {
        Write-Host "Asset.Automation role already assigned to E2E service principal."
    }
}

# ── .NET user-secrets ─────────────────────────────────────────────────────────
$userSecrets = @{
    "EntraExternalId:TenantId"          = $TenantId
    "EntraExternalId:ClientId"          = $e2eApp.AppId
    "BackEndApi:ClientId"               = $ApiAppId
}
if ($e2eSecret) {
    $userSecrets["EntraExternalId:ClientSecret"] = $e2eSecret
}
Set-ProjectUserSecrets -ProjectPath $ProjectPath -Secrets $userSecrets

Write-Host "E2E app registration complete: $AppRegistrationName ($($e2eApp.AppId))"

# ── Normalized return contract ─────────────────────────────────────────────────
return [PSCustomObject]@{
    AppId              = $e2eApp.AppId
    ObjectId           = $e2eApp.Id
    ServicePrincipalId = if ($e2eSp) { $e2eSp.Id } else { "" }
    Type               = "E2E"
    Created            = $created
    Capabilities       = @("application")
    Secret             = $e2eSecret   # $null unless -GenerateSecrets was set
}
