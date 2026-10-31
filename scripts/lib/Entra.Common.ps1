# Shared helpers for the Entra scripts. Dot-source it: . "$PSScriptRoot\..\lib\Entra.Common.ps1"

function Install-EntraPrerequisites {
    param([string[]]$Modules = @('Az.Accounts', 'Az.Resources', 'Microsoft.Graph.Applications'))
    foreach ($module in $Modules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing PowerShell module: $module"
            Install-Module $module -Scope CurrentUser -Force
        }
        Import-Module $module -ErrorAction Stop
    }
}

# Signs in to Azure and Microsoft Graph for one tenant, reusing an existing session when it already has the scopes.
function Connect-EntraSession {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [string[]]$GraphScopes = @('Application.ReadWrite.All', 'Directory.ReadWrite.All')
    )

    $azContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
        Write-Host "Logging into Azure tenant $TenantId..."
        Connect-AzAccount -Tenant $TenantId | Out-Null
    }

    $mgContext = $null
    try { $mgContext = Get-MgContext -ErrorAction Stop } catch {}
    $hasScopes = $mgContext -and $mgContext.Scopes -and (@($GraphScopes | Where-Object { $_ -notin $mgContext.Scopes }).Count -eq 0)
    if (-not $mgContext -or $mgContext.TenantId -ne $TenantId -or -not $hasScopes) {
        Write-Host "Connecting to Microsoft Graph..."
        Connect-MgGraph -TenantId $TenantId -Scopes $GraphScopes -NoWelcome | Out-Null
        $mgContext = Get-MgContext -ErrorAction Stop
        if (-not $mgContext -or $mgContext.TenantId -ne $TenantId) {
            throw "Microsoft Graph sign-in did not produce a context for tenant $TenantId."
        }
    }
}
