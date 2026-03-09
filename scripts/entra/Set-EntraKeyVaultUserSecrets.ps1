# ============================================================================
# Script Name:   Set-EntraKeyVaultUserSecrets.ps1
# Description:   Copies .NET user-secrets from API and Web projects to Azure Key Vault, prefixing secrets with product and project names.
# -----------------------------------------------------------------------------
# Example CLI Usage:
#   # Minimal example (uses defaults for project paths, project names, and dotnet version):
#   pwsh -File ./Set-EntraKeyVaultUserSecrets.ps1  -TenantId "<tenant-id>" -SubscriptionId "<subscription-id>" -KeyVaultName "my-kv" -ProductName "studio"
#
#   # Full example:
#   pwsh -File ./Set-EntraKeyVaultUserSecrets.ps1 `
#       -ApiProjectPath "../../src/Presentation.WebApi" `
#       -WebProjectPath "../../src/Presentation.Blazor" `
#       -KeyVaultName "my-keyvault-name" `
#       -TenantId "<tenant-id>" `
#       -ProductName "studio" `
#       -ApiProjectName "Api" `
#       -WebProjectName "Web" `
#       -DotNetVersion "10" `
#       -SubscriptionId "<subscription-id>"
# -----------------------------------------------------------------------------
# Notes:
#   - Requires Azure CLI and .NET SDK installed.
#   - Authenticates to the Key Vault tenant only.
#   - Idempotent: existing secrets in Key Vault will be overwritten with latest values.
#   - Key Vault secret names will be prefixed as: <ProductName><ProjectName>-<UserSecretKey>
# ============================================================================
param(
    [Parameter(Mandatory)][string]$TenantId,       
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$KeyVaultName,    
    [Parameter(Mandatory)][string]$ProductName,
    [string]$WebProjectName = "Web",
    [string]$ApiProjectName = "Api",
    [string]$WebProjectPath = "../../src/Presentation.Blazor",
    [string]$ApiProjectPath = "../../src/Presentation.WebApi",
    [string]$DotNetVersion = "10"
)

function Install-Prerequisites {
    param(
        [string]$DotNetVersion
    )
    Write-Host "Checking prerequisites..."
    $dotnetInstalled = & dotnet --list-sdks | Select-String "^$DotNetVersion\."
    if (-not $dotnetInstalled) {
        Write-Host ".NET SDK $DotNetVersion not found. Installing via winget..."
        winget install --id Microsoft.DotNet.SDK.$DotNetVersion -e --silent
    } else {
        Write-Host ".NET SDK $DotNetVersion is already installed."
    }
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI (az) is not installed. Please install it and re-run the script."
        exit 1
    }
}

function Import-UserSecrets {
    param(
        [string]$ProjectPath
    )
    $secrets = @{}
    if (Test-Path $ProjectPath) {
        Push-Location $ProjectPath
        $output = dotnet user-secrets list 2>$null
        Pop-Location
        foreach ($line in $output) {
            if ($line -match '^(.*)\s*=\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $secrets[$key] = $value
            }
        }
    } else {
        Write-Warning "*** CRITICAL: Project path '$ProjectPath' not found. Skipping. ***"
    }
    return $secrets
}

# Step 1: Install prerequisites
Install-Prerequisites -DotNetVersion $DotNetVersion

# Step 2: Authenticate to Azure Key Vault tenant
Write-Host "Authenticating to Azure tenant for Key Vault..."
az login --tenant $TenantId | Out-Null
if ($SubscriptionId) {
    Write-Host "Setting Azure subscription context..."
    az account set --subscription $SubscriptionId
}

# Step 3: Import user-secrets from API and Web projects
$apiSecrets = Import-UserSecrets -ProjectPath $ApiProjectPath
$webSecrets = Import-UserSecrets -ProjectPath $WebProjectPath

# Step 4: Write secrets to Key Vault with prefix
Write-Host "Writing API secrets to Key Vault..."
foreach ($key in $apiSecrets.Keys) {
    $kvSecretName = \"${ProductName}${ApiProjectName}-$key\"
    az keyvault secret set --vault-name $KeyVaultName --name $kvSecretName --value $apiSecrets[$key] | Out-Null
    Write-Host \"Set secret: $kvSecretName\"
}
Write-Host "Writing Web secrets to Key Vault..."
foreach ($key in $webSecrets.Keys) {
    $kvSecretName = \"${ProductName}${WebProjectName}-$key\"
    az keyvault secret set --vault-name $KeyVaultName --name $kvSecretName --value $webSecrets[$key] | Out-Null
    Write-Host \"Set secret: $kvSecretName\"
}

Write-Host "All user-secrets written to Key Vault '$KeyVaultName' with product/project prefix."