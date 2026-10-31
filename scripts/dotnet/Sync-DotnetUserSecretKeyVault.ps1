<#
.SYNOPSIS
Copies one project's .NET user-secrets to Azure Key Vault, or from Key Vault into the project's user-secrets.

.DESCRIPTION
ToKeyVault stores each user-secret as <ProductName><ProjectName>-<key>, with ':' written as '--' because Key Vault names allow only letters, digits and hyphens.
FromKeyVault reverses that for the same prefix, which sets up a new developer machine without creating a new client secret.
Existing values are overwritten with the latest ones.

.EXAMPLE
# Publish the Web project's user-secrets (single line, safe to paste):
pwsh -File ./dotnet/Sync-DotnetUserSecretKeyVault.ps1 -Direction ToKeyVault -TenantId "<tenant-id>" -SubscriptionId "<subscription-id>" -KeyVaultName "my-kv" -ProductName "compass" -ProjectName "Web" -ProjectPath "./src/Presentation.Web"

.EXAMPLE
# Restore them on a new machine (single line, safe to paste):
pwsh -File ./dotnet/Sync-DotnetUserSecretKeyVault.ps1 -Direction FromKeyVault -TenantId "<tenant-id>" -SubscriptionId "<subscription-id>" -KeyVaultName "my-kv" -ProductName "compass" -ProjectName "Web" -ProjectPath "./src/Presentation.Web"

.NOTES
- Requires the .NET SDK and the Az.Accounts and Az.KeyVault modules.
- The signed-in user needs permission to set (ToKeyVault) or get and list (FromKeyVault) secrets.
- Relative paths resolve from the current directory.
#>
param(
    [Parameter(Mandatory)][ValidateSet('ToKeyVault', 'FromKeyVault')][string]$Direction,
    [Parameter(Mandatory)][string]$TenantId,
    [string]$SubscriptionId = '',
    [Parameter(Mandatory)][string]$KeyVaultName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Za-z]+$')][string]$ProductName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9A-Za-z]+$')][string]$ProjectName,
    [Parameter(Mandatory)][string]$ProjectPath
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\lib\Entra.Common.ps1"
. "$PSScriptRoot\..\lib\Dotnet.Common.ps1"

Install-EntraPrerequisites -Modules @('Az.Accounts', 'Az.KeyVault')
$azContext = Get-AzContext -ErrorAction SilentlyContinue
if (-not $azContext -or $azContext.Tenant.Id -ne $TenantId) {
    Connect-AzAccount -Tenant $TenantId | Out-Null
}
if ($SubscriptionId) { Set-AzContext -Subscription $SubscriptionId -Tenant $TenantId | Out-Null }

$prefix = "$ProductName$ProjectName-"

if ($Direction -eq 'ToKeyVault') {
    $secrets = Get-DotnetUserSecrets -ProjectPath $ProjectPath
    if ($secrets.Count -eq 0) { throw "No user-secrets found for '$ProjectPath'." }
    foreach ($key in $secrets.Keys) {
        $name = $prefix + $key.Replace(':', '--')
        if ($name -notmatch '^[0-9A-Za-z-]{1,127}$') { throw "Secret name '$name' is not valid for Key Vault." }
        Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name -SecretValue (ConvertTo-SecureString $secrets[$key] -AsPlainText -Force) | Out-Null
        Write-Host "Set secret: $name"
    }
    Write-Host "Copied $($secrets.Count) user-secrets to Key Vault '$KeyVaultName'."
    return
}

$names = @(Get-AzKeyVaultSecret -VaultName $KeyVaultName | Where-Object { $_.Name -like "$prefix*" } | ForEach-Object { $_.Name })
if ($names.Count -eq 0) { throw "No secrets named '$prefix*' found in Key Vault '$KeyVaultName'." }
$restored = @{}
foreach ($name in $names) {
    $restored[$name.Substring($prefix.Length).Replace('--', ':')] = Get-AzKeyVaultSecret -VaultName $KeyVaultName -Name $name -AsPlainText
}
$stored = Save-DotnetUserSecrets -ProjectPath $ProjectPath -Secrets $restored -Label $ProjectName
if (-not $stored) { throw "The user-secrets for '$ProjectPath' were not written." }
Write-Host "Restored $($restored.Count) secrets from Key Vault '$KeyVaultName'."
