<#
.SYNOPSIS
Ensures separate runtime and migration Entra service-principal users in one Azure SQL database.
.DESCRIPTION
Run as an already authorized SQL Entra administrator/bootstrap principal after database deployment.
Uses explicit application/client IDs (SID/TYPE), not Microsoft Graph display-name resolution. This does not
create Entra objects, grant Azure RBAC, run migrations, or alter server authentication.
Requires Azure CLI login and the SqlServer PowerShell module. No credentials are written or printed.
.EXAMPLE
pwsh -File .\scripts\sql\Set-AzureSqlManagedIdentityUsers.ps1 -ServerHost product.database.windows.net -DatabaseName product -RuntimeName product-api -RuntimeClientId <api-identity-client-id> -MigrationName product-migrations -MigrationClientId <deployment-client-id>
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[a-zA-Z0-9.-]+$')][string]$ServerHost,
    [Parameter(Mandatory)][ValidateLength(1, 128)][string]$DatabaseName,
    [Parameter(Mandatory)][ValidateLength(1, 128)][string]$RuntimeName,
    [Parameter(Mandatory)][guid]$RuntimeClientId,
    [Parameter(Mandatory)][ValidateLength(1, 128)][string]$MigrationName,
    [Parameter(Mandatory)][guid]$MigrationClientId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\lib\AzureSql.Common.ps1"

$query = New-AzureSqlPrincipalBatch -RuntimeName $RuntimeName -RuntimeClientId $RuntimeClientId `
    -MigrationName $MigrationName -MigrationClientId $MigrationClientId
if (-not (Get-Module -ListAvailable SqlServer | Where-Object { $_.Version -ge [version]'22.0' })) {
    throw 'SqlServer PowerShell module 22 or later is required. Install-Module SqlServer -Scope CurrentUser.'
}
Import-Module SqlServer -MinimumVersion 22.0

$tokenJson = az account get-access-token --resource https://database.windows.net/ --output json
if ($LASTEXITCODE -ne 0) { throw 'Azure CLI could not acquire the SQL access token. Sign in to the workload tenant first.' }
$token = ($tokenJson | ConvertFrom-Json).accessToken
if ([string]::IsNullOrWhiteSpace($token)) { throw 'Azure CLI returned no SQL access token.' }

Invoke-Sqlcmd -ServerInstance "tcp:$ServerHost,1433" -Database $DatabaseName -AccessToken $token `
    -Query $query -Encrypt Mandatory -AbortOnError -ErrorAction Stop
Write-Host "SQL runtime and migration users configured for database '$DatabaseName'."
