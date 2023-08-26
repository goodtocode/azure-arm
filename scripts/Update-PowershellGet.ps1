#-----------------------------------------------------------------------
# Update-PowerShellGet 
#
# Description: Brings older OS up to speed, so we can install Az modules
#
# Example: .\Update-PowerShellGet
#-----------------------------------------------------------------------

# ***
# *** Parameters
# ***
param
(

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
Write-Host "TLS 1.2 or above must be enabled"
Install-PackageProvider -Name NuGet -Force
Install-Module PowerShellGet -AllowClobber -Force
# Close/re-open powershell
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted