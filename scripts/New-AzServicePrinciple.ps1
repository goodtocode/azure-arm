#-----------------------------------------------------------------------
# New-AzServicePrinciple [-TenantId [<Guid>]] [-SubscriptionId [<Guid>]]
#
# Example: .\Remove-LandingZone -TenantId -SubscriptionId -ResourceGroup -KeyVault -StorageAccount -Workspace
# CLI: az ad sp create-for-rbac --name "myApp" --role contributor \
#        --scopes /subscriptions/{subscription-id}/resourceGroups/{resource-group} --sdk-auth
#-----------------------------------------------------------------------

# ***
# *** Parameters
# ***
param
(
    [string] $Name=$(throw '-Name is a required parameter. (myco-product-environment)'),
    [string] $TenantId=$(throw '-TenantId is a required parameter. (00000000-0000-0000-0000-000000000000)'),
    [string] $SubscriptionId=$(throw '-SubscriptionId is a required parameter. (00000000-0000-0000-0000-000000000000)')
)

# ***
# *** Initialize
# ***
if ($IsWindows) { Set-ExecutionPolicy Unrestricted -Scope Process -Force }
$VerbosePreference = 'SilentlyContinue' #'Continue'
[String]$ThisScript = $MyInvocation.MyCommand.Path
[String]$ThisDir = Split-Path $ThisScript
[DateTime]$Now = Get-Date
Set-Location $ThisDir # Ensure our location is correct, so we can use relative paths
Write-Host "*****************************"
Write-Host "*** Starting: $ThisScript on $Now"
Write-Host "*****************************"
# Imports
Import-Module "./System.psm1"
Install-Module -Name Az.Accounts -AllowClobber -Scope CurrentUser
Install-Module -Name Az.Resources -AllowClobber -Scope CurrentUser

# ***
# *** Auth
# ***
Write-Host "*** Auth ***"
Connect-AzAccount -Tenant $TenantId -Subscription $SubscriptionId

$sp = New-AzADServicePrincipal -DisplayName $Name 
$clientsec = [System.Net.NetworkCredential]::new("", $sp.passwordCredentials.secretText).Password
$jsonresp = 
    @{clientId=$sp.appId 
        clientSecret=$clientsec
        subscriptionId=$SubscriptionId
        tenantId=$TenantId}
$jsonresp | ConvertTo-Json

