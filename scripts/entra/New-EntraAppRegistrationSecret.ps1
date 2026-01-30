# ============================================================================
# Script Name:   New-EeidAppRegistrationSecret.ps1
# Description:   Creates a new client secret for an existing Entra External ID App Registration.
# -----------------------------------------------------------------------------
# Example CLI Usage:
#   pwsh -File ./scripts/entra-external-id/New-EeidAppRegistrationSecret.ps1 -TenantId "<your-tenant-id>" -SubscriptionId "<your-subscription-id>" -AppRegistrationName "<web-app-name>"
# -----------------------------------------------------------------------------
# Notes:
#   - Requires Azure PowerShell modules (Az.Accounts, Az.Resources, etc.)
#   - Ensure you are authenticated: Connect-AzAccount
# ============================================================================
param(
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$AppRegistrationName,
    [int]$SecretMonths = 24
)

# Step 1: Install prerequisites (az cli, modules)
Write-Host "Checking prerequisites..."
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "Azure CLI not found. Installing via winget..."
    winget install --id Microsoft.AzureCLI -e --silent
} else {
    Write-Host "Azure CLI is already installed."
}

$modules = @("Az.Accounts", "Az.Resources")
foreach ($module in $modules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing PowerShell module: $module"
        Install-Module $module -Scope CurrentUser -Force
    } else {
        Write-Host "PowerShell module $module is already installed."
    }
}

# Step 2: Login to Azure and set tenant/subscription
Write-Host "Logging into Azure..."
$azLoggedIn = az account show 2>$null
if (-not $azLoggedIn) {
    az login --tenant $TenantId
    Write-Host "Logged in to Azure tenant $TenantId."
} else {
    Write-Host "Already logged in to Azure."
}

Write-Host "Setting Azure subscription..."
$currentSub = az account show --query id -o tsv
if ($currentSub -ne $SubscriptionId) {
    az account set --subscription $SubscriptionId
    Write-Host "Azure subscription set to $SubscriptionId."
} else {
    Write-Host "Azure subscription already set to $SubscriptionId."
}

# Step 3: Find the app registration
Write-Host "Finding app registration: $AppRegistrationName..."
$app = az ad app list --display-name $AppRegistrationName --query "[0]" -o json | ConvertFrom-Json
if (-not $app) {
    Write-Error "App registration '$AppRegistrationName' not found. Cannot create secret."
    exit 1
}
$appId = $app.appId

# Step 4: Create new client secret
$secret = az ad app credential reset --id $appId --display-name "$AppRegistrationName-$(Get-Date -Format yyyy)" --months $SecretMonths --query "secretText" -o tsv
if ($secret) {
    Write-Host "Created new client secret for app registration '$AppRegistrationName'."
    Write-Host "Secret value: $secret"
} else {
    Write-Error "Failed to create client secret."
}
