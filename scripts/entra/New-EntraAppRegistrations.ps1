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
	[string]$WebAppRegistrationName = "semker-deleteme-web",
	[string]$WebProjectPath = "../../src/Presentation.Blazor",
	[string]$ApiAppRegistrationName = "semker-deleteme-api",
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
}
else {
	Write-Host ".NET SDK $DotNetVersion is already installed."
}

# Check and install PowerShell modules
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

# Step 2: Login to Azure and set EEID tenant
Write-Host "Checking Azure authentication..."
$azContext = Get-AzContext -ErrorAction SilentlyContinue
if ($azContext -and $azContext.Tenant.Id -eq $TenantId) {
	Write-Host "Already authenticated to Azure tenant $TenantId."
}
else {
	Write-Host "Logging into Azure..."
	Connect-AzAccount -Tenant $TenantId | Out-Null
	Write-Host "Logged in to Azure tenant $TenantId."
}
# Ensure Microsoft Graph is authenticated
$mgContext = $null
try {
	$mgContext = Get-MgContext -ErrorAction Stop
}
catch {}
if ($mgContext -and $mgContext.TenantId -eq $TenantId -and $mgContext.Account) {
	Write-Host "Already authenticated to Microsoft Graph for tenant $TenantId."
}
else {
	try {
		Write-Host "Connecting to Microsoft Graph..."
		Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All" | Out-Null
		$mgContext = Get-MgContext -ErrorAction Stop
		Write-Host "Connected to Microsoft Graph for tenant $TenantId."
	}
 catch {
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
		$apiApp = New-MgApplication -DisplayName $ApiAppRegistrationName -SignInAudience AzureADMyOrg
	}
	catch {
		Write-Error "FATAL: Failed to create API app registration. $_.Exception.Message"
		exit 1
	}
	if (-not $apiApp -or -not $apiApp.AppId) {
		Write-Error "FATAL: API app registration was not created. Exiting script."
		exit 1
	}
	$apiAppId = $apiApp.AppId
	Write-Host "Created API app registration with appId: $apiAppId"
	# Set IdentifierUri to api://<AppId>
	$identifierUri = "api://$apiAppId"
	Update-MgApplication -ApplicationId $apiApp.Id -IdentifierUris @($identifierUri)
	Write-Host "Set IdentifierUri to $identifierUri"
	# Add custom scopes
	$customScopes = @(
		@{
			Id                      = [guid]::NewGuid()
			AdminConsentDisplayName = "Read assets"
			AdminConsentDescription = "Allows the app to view asset data."
			UserConsentDisplayName  = "Read your assets"
			UserConsentDescription  = "Allows the app to view your assets."
			IsEnabled               = $true
			Type                    = "User"
			Value                   = "assets.read"
		},
		@{
			Id                      = [guid]::NewGuid()
			AdminConsentDisplayName = "Edit assets"
			AdminConsentDescription = "Allows the app to create or update asset data."
			UserConsentDisplayName  = "Edit your assets"
			UserConsentDescription  = "Allows the app to create or update your assets."
			IsEnabled               = $true
			Type                    = "User"
			Value                   = "assets.write"
		},
		@{
			Id                      = [guid]::NewGuid()
			AdminConsentDisplayName = "Delete assets"
			AdminConsentDescription = "Allows the app to delete asset data."
			UserConsentDisplayName  = "Delete your assets"
			UserConsentDescription  = "Allows the app to delete your assets."
			IsEnabled               = $true
			Type                    = "User"
			Value                   = "assets.delete"
		}
	)
	Update-MgApplication -ApplicationId $apiApp.Id -Api @{ OAuth2PermissionScopes = $customScopes }
	Write-Host "Added custom OAuth2 permission scopes to API app registration."
	# Add app roles
	$appRoles = @(
		@{
			Id                 = [guid]::NewGuid()
			AllowedMemberTypes = @("User")
			Description        = "Can view assets only."
			DisplayName        = "Asset Viewer"
			IsEnabled          = $true
			Origin             = "Application"
			Value              = "AssetViewer"
		},
		@{
			Id                 = [guid]::NewGuid()
			AllowedMemberTypes = @("User")
			Description        = "Can view and edit assets."
			DisplayName        = "Asset Editor"
			IsEnabled          = $true
			Origin             = "Application"
			Value              = "AssetEditor"
		},
		@{
			Id                 = [guid]::NewGuid()
			AllowedMemberTypes = @("User")
			Description        = "Can view, edit, and delete assets."
			DisplayName        = "Asset Admin"
			IsEnabled          = $true
			Origin             = "Application"
			Value              = "AssetAdmin"
		}
	)
	Update-MgApplication -ApplicationId $apiApp.Id -AppRoles $appRoles
	Write-Host "Added app roles to API app registration."
}
else {
	Write-Host "API app registration $ApiAppRegistrationName already exists."
	$apiAppId = $apiApp.AppId
}

# Always add Microsoft Graph User.Read delegated permission to API app registration
Write-Host "Adding Microsoft Graph User.Read permission to API app registration..."
$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
if (-not $msGraphSp) {
	Write-Error "FATAL: Microsoft Graph service principal not found. Exiting script."
	exit 1
}
$userReadPerm = $msGraphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq "User.Read" }
if (-not $userReadPerm) {
	Write-Error "FATAL: Microsoft Graph User.Read permission not found. Exiting script."
	exit 1
}
$apiAppReqPerms = @{
	ResourceAppId  = $msGraphSp.AppId
	ResourceAccess = @(@{
			Id   = $userReadPerm.Id
			Type = "Scope"
		})
}
Update-MgApplication -ApplicationId $apiApp.Id -RequiredResourceAccess @($apiAppReqPerms)
Write-Host "Added Microsoft Graph User.Read delegated permission to API app registration."

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
}
else {
	Write-Warning "*** CRITICAL: API project path '$ApiProjectPath' not found. Skipping dotnet user-secrets for API. App registrations will continue, but user-secrets are NOT set. ***"
}

# Step 5: Check for Web app registration by name; create if missing
Write-Host "Checking for Web app registration: $WebAppRegistrationName..."
$webApp = Get-MgApplication -Filter "displayName eq '$WebAppRegistrationName'" -ErrorAction SilentlyContinue
if (-not $webApp) {
	Write-Host "Web app registration not found. Creating..."
	try {
		$webApp = New-MgApplication -DisplayName $WebAppRegistrationName -SignInAudience AzureADMyOrg -Web @{ RedirectUris = @($WebRedirectUri); LogoutUrl = $WebLogoutUri }
	}
 catch {
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
	}
 catch {
		Write-Error "FATAL: Failed to create client secret for Web app registration. $_.Exception.Message"
		exit 1
	}
	if (-not $webSecretObj -or -not $webSecretObj.SecretText) {
		Write-Error "FATAL: Web app client secret was not created. Exiting script."
		exit 1
	}
	$webSecret = $webSecretObj.SecretText
	Write-Host "Created client secret for Web app registration."
	# Add Microsoft Graph delegated permissions: User.Read, email, profile
	Write-Host "Adding Microsoft Graph User.Read, email, profile delegated permissions to Web app registration..."
	$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
	if (-not $msGraphSp) {
		Write-Error "FATAL: Microsoft Graph service principal not found. Exiting script."
		exit 1
	}
	$delegatedPerms = @("User.Read", "email", "profile")
	$permScopes = @()
	foreach ($perm in $delegatedPerms) {
		$scope = $msGraphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm }
		if (-not $scope) {
			Write-Error "FATAL: Microsoft Graph permission $perm not found. Exiting script."
			exit 1
		}
		$permScopes += @{ Id = $scope.Id; Type = "Scope" }
	}
	$webAppReqPerms = @{
		ResourceAppId  = $msGraphSp.AppId
		ResourceAccess = $permScopes
	}
	Update-MgApplication -ApplicationId $webApp.Id -RequiredResourceAccess @($webAppReqPerms)
	Write-Host "Added Microsoft Graph User.Read, email, profile delegated permissions to Web app registration."
}
else {
	Write-Host "Web app registration $WebAppRegistrationName already exists."
	$webAppId = $webApp.AppId
	# Add Microsoft Graph delegated permissions: User.Read, email, profile
	Write-Host "Adding Microsoft Graph User.Read, email, profile delegated permissions to Web app registration..."
	$msGraphSp = Get-MgServicePrincipal -Filter "displayName eq 'Microsoft Graph'" -ErrorAction Stop
	if (-not $msGraphSp) {
		Write-Error "FATAL: Microsoft Graph service principal not found. Exiting script."
		exit 1
	}
	$delegatedPerms = @("User.Read", "email", "profile")
	$permScopes = @()
	foreach ($perm in $delegatedPerms) {
		$scope = $msGraphSp.Oauth2PermissionScopes | Where-Object { $_.Value -eq $perm }
		if (-not $scope) {
			Write-Error "FATAL: Microsoft Graph permission $perm not found. Exiting script."
			exit 1
		}
		$permScopes += @{ Id = $scope.Id; Type = "Scope" }
	}
	$webAppReqPerms = @{
		ResourceAppId  = $msGraphSp.AppId
		ResourceAccess = $permScopes
	}
	Update-MgApplication -ApplicationId $webApp.Id -RequiredResourceAccess @($webAppReqPerms)
	Write-Host "Added Microsoft Graph User.Read, email, profile delegated permissions to Web app registration."
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
}
else {
	Write-Warning "*** CRITICAL: Web project path '$WebProjectPath' not found. Skipping dotnet user-secrets for Web. App registrations will continue, but user-secrets are NOT set. ***"
}
