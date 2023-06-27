#-----------------------------------------------------------------------
# Set-Tls 
#
# Example: .\Set-Tls
#-----------------------------------------------------------------------

# ***
# *** Parameters
# ***
param
(
	[string] $TenantId=$(throw '-TenantId is a required parameter. (00000000-0000-0000-0000-000000000000)'),
    [string] $SubscriptionId=$(throw '-TenantId is a required parameter. (00000000-0000-0000-0000-000000000000)'),
	[string] $ResourceGroup=$(throw '-ResourceGroup is a required parameter. (rg-PRODUCT-ENVIRONMENT-001)'),
    [string] $KeyVault=$(throw '-KeyVault is a required parameter. (kv-PRODUCT-ENVIRONMENT-001)'),
    [string] $StorageAccount=$(throw '-StorageAccount is a required parameter. (stPRODUCTENVIRONMENT001)'),
    [string] $Workspace=$(throw '-Workspace is a required parameter. (work-PRODUCT-ENVIRONMENT-001)')
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

# ***
# *** Execute
# ***
Write-Host [Net.ServicePointManager]::SecurityProtocol
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\.NetFramework\v4.0.30319' -Name 'SchUseStrongCrypto' -Value '1' -Type DWord
Write-Host [Net.ServicePointManager]::SecurityProtocol