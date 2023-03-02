####################################################################################
# To execute
#   1. Run Powershell as ADMINistrator
#   2. In powershell, set security polilcy for this script: 
#      Set-ExecutionPolicy Unrestricted -Scope Process -Force
#   3. Change directory to the script folder:
#      CD C:\Temp (wherever your script is)
#   4. In powershell, run script: 
#      .\Get-AadSecrets.ps1
####################################################################################


####################################################################################
Set-ExecutionPolicy Unrestricted -Scope Process -Force
$VerbosePreference = 'SilentlyContinue' # 'SilentlyContinue' # 'Continue'
[String]$ThisScript = $MyInvocation.MyCommand.Path
[String]$ThisDir = Split-Path $ThisScript
Set-Location $ThisDir # Ensure our location is correct, so we can use relative paths
Write-Host "*****************************"
Write-Host "*** Starting: $ThisScript On: $(Get-Date)"
Write-Host "*****************************"
####################################################################################
# Imports
Install-Module -Name ImportExcel

# Connect to Azure Active Directory
Connect-AzureAD

# Get secrets that are expiring within 30 days
$secrets = Get-AzureADApplication | Select-Object -ExpandProperty PasswordCredentials | Where-Object { $_.EndDate -le (Get-Date).AddDays(30) }

# Get certificates that are expiring within 30 days
$certificates = Get-AzureADApplication | Select-Object -ExpandProperty KeyCredentials | Where-Object { $_.EndDate -le (Get-Date).AddDays(30) }

# Combine secrets and certificates
$expiringCredentials = $secrets + $certificates

# Export to Excel
$excelFilePath = "C:\temp\AzureADExpiringCredentials.xlsx"
$expiringCredentials | Export-Excel -Path $excelFilePath -AutoSize -AutoFilter -FreezeTopRow -WorksheetName "ExpiringCredentials"