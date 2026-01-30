# ============================================================================
# Script Name:   New-EeidAppRegistrations.ps1
# Description:   Creates new Entra External ID App Registrations.
# -----------------------------------------------------------------------------
# Example CLI Usage:
#   pwsh -File ./New-EntraAppRegistrations.ps1 -EntraInstanceUrl "<your-eeid-instance-url>" -TenantId "<your-tenant-id>"
# -----------------------------------------------------------------------------
# Notes:
#   - Requires Azure PowerShell modules (Az.Accounts, Az.Resources, etc.)
#   - Ensure you are authenticated: Connect-AzAccount
# ============================================================================
param(
	[string]$EntraInstanceUrl,
	[string]$TenantId,
	[string]$WebAppRegistrationName = "web-semker-deleteme",
	[string]$WebProjectPath = "../../src/Presentation.Blazor",
	[string]$ApiAppRegistrationName = "api-semker-deleteme",
	[string]$ApiProjectPath = "../../src/Presentation.WebApi",
	[string]$DotNetVersion = "10",
	[string]$WebRedirectUri = "https://localhost:7175/signin-oidc",
	[string]$WebLogoutUri = "https://localhost:7175/signout-callback-oidc"
)


# Step 1: Install prerequisites (dotnet sdk, modules)
Write-Host "Checking prerequisites..."

# Check and install .NET SDK
$dotnetInstalled = & dotnet --list-sdks | Select-String "^$DotNetVersion\."
if (-not $dotnetInstalled) {
	Write-Host ".NET SDK $DotNetVersion not found. Installing via winget..."
	winget install --id Microsoft.DotNet.SDK.$DotNetVersion -e --silent
} else {
	Write-Host ".NET SDK $DotNetVersion is already installed."
}

# Check and install PowerShell modules
$modules = @("Az.Accounts", "Az.Resources", "Microsoft.Graph.Applications")
foreach ($module in $modules) {
	if (-not (Get-Module -ListAvailable -Name $module)) {
		Write-Host "Installing PowerShell module: $module"
		Install-Module $module -Scope CurrentUser -Force
	} else {
		Write-Host "PowerShell module $module is already installed."
	}
}

# Step 2: Login to Azure and set EEID tenant
Write-Host "Checking Azure authentication..."
$azContext = Get-AzContext -ErrorAction SilentlyContinue
if ($azContext -and $azContext.Tenant.Id -eq $TenantId) {
	Write-Host "Already authenticated to Azure tenant $TenantId."
} else {
	Write-Host "Logging into Azure..."
	Connect-AzAccount -Tenant $TenantId | Out-Null
	Write-Host "Logged in to Azure tenant $TenantId."
}

# Ensure Microsoft Graph is authenticated
$mgContext = $null
try {
	$mgContext = Get-MgContext -ErrorAction Stop
} catch {}
if ($mgContext -and $mgContext.TenantId -eq $TenantId -and $mgContext.Account) {
	Write-Host "Already authenticated to Microsoft Graph for tenant $TenantId."
} else {
	try {
		Write-Host "Connecting to Microsoft Graph..."
		Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All","Directory.ReadWrite.All" | Out-Null
		$mgContext = Get-MgContext -ErrorAction Stop
		Write-Host "Connected to Microsoft Graph for tenant $TenantId."
	} catch {
		Write-Error "FATAL: Microsoft Graph authentication failed. Exiting script."
		exit 1
	}
}

# Step 3: Check for API app registration by name; create if missing
Write-Host "Checking for API app registration: $ApiAppRegistrationName..."
Import-Module Microsoft.Graph.Applications
$apiApp = Get-MgApplication -Filter "displayName eq '$ApiAppRegistrationName'" -ErrorAction SilentlyContinue
if (-not $apiApp) {
	Write-Host "API app registration not found. Creating..."
	try {
		$apiApp = New-MgApplication -DisplayName $ApiAppRegistrationName -SignInAudience AzureADMyOrg -IdentifierUri ("api://$ApiAppRegistrationName")
	} catch {
		Write-Error "FATAL: Failed to create API app registration. $_.Exception.Message"
		exit 1
	}
	if (-not $apiApp -or -not $apiApp.AppId) {
		Write-Error "FATAL: API app registration was not created. Exiting script."
		exit 1
	}
	$apiAppId = $apiApp.AppId
	Write-Host "Created API app registration with appId: $apiAppId"
} else {
	Write-Host "API app registration $ApiAppRegistrationName already exists."
	$apiAppId = $apiApp.AppId
}

# Step 4: Write API EEID values to $ApiProjectPath via dotnet user-secrets
if (Test-Path $ApiProjectPath) {
	Write-Host "Setting EntraExternalId values for $ApiProjectPath"
	Push-Location $ApiProjectPath
	dotnet user-secrets init
	dotnet user-secrets set "EntraExternalId:Instance" $EntraInstanceUrl
	dotnet user-secrets set "EntraExternalId:TenantId" $TenantId
	dotnet user-secrets set "EntraExternalId:ClientId" $apiApp.appId
	dotnet user-secrets set "EntraExternalId:ValidateAuthority" "true"
	Pop-Location
} else {
	Write-Warning "*** CRITICAL: API project path '$ApiProjectPath' not found. Skipping dotnet user-secrets for API. App registrations will continue, but user-secrets are NOT set. ***"
}

# Step 5: Check for Web app registration by name; create if missing
Write-Host "Checking for Web app registration: $WebAppRegistrationName..."
$webApp = Get-MgApplication -Filter "displayName eq '$WebAppRegistrationName'" -ErrorAction SilentlyContinue
if (-not $webApp) {
	Write-Host "Web app registration not found. Creating..."
	try {
		$webApp = New-MgApplication -DisplayName $WebAppRegistrationName -SignInAudience AzureADMyOrg -Web @{ RedirectUris = @($WebRedirectUri); LogoutUrl = $WebLogoutUri }
	} catch {
		Write-Error "FATAL: Failed to create Web app registration. $_.Exception.Message"
		exit 1
	}
	if (-not $webApp -or -not $webApp.AppId) {
		Write-Error "FATAL: Web app registration was not created. Exiting script."
		exit 1
	}
	$webAppId = $webApp.AppId
	Write-Host "Created Web app registration with appId: $webAppId"
	# Create client secret
	try {
		$passwordCredential = @{ EndDateTime = (Get-Date).AddYears(2) }
		$webSecretObj = Add-MgApplicationPassword -ApplicationId $webApp.Id -PasswordCredential $passwordCredential
	} catch {
		Write-Error "FATAL: Failed to create client secret for Web app registration. $_.Exception.Message"
		exit 1
	}
	if (-not $webSecretObj -or -not $webSecretObj.SecretText) {
		Write-Error "FATAL: Web app client secret was not created. Exiting script."
		exit 1
	}
	$webSecret = $webSecretObj.SecretText
	Write-Host "Created client secret for Web app registration."
} else {
	Write-Host "Web app registration $WebAppRegistrationName already exists."
	$webAppId = $webApp.AppId
}

# Step 6: Write Web EEID values to $WebProjectPath via dotnet user-secrets
if (Test-Path $WebProjectPath) {
	Write-Host "Setting EntraExternalId values for $WebProjectPath"
	Push-Location $WebProjectPath
	dotnet user-secrets init
	dotnet user-secrets set "EntraExternalId:Instance" $EntraInstanceUrl
	dotnet user-secrets set "EntraExternalId:TenantId" $TenantId
	dotnet user-secrets set "EntraExternalId:ClientId" $webApp.AppId
	dotnet user-secrets set "EntraExternalId:ValidateAuthority" "true"
	dotnet user-secrets set "EntraExternalId:ClientSecret" $webSecret
	Pop-Location
} else {
	Write-Warning "*** CRITICAL: Web project path '$WebProjectPath' not found. Skipping dotnet user-secrets for Web. App registrations will continue, but user-secrets are NOT set. ***"
}
