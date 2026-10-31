<#
.SYNOPSIS
Writes key/value pairs to a .NET project's user-secrets.

.DESCRIPTION
Accepts a project folder or a .csproj path. Returns $true when every value was stored. When it cannot store them, the secret values (keys containing Secret or Password) are printed once so they are not lost.

.EXAMPLE
# Single line, safe to paste:
pwsh -Command "& ./dotnet/Set-DotnetUserSecret.ps1 -ProjectPath ./src/Presentation.Api -Secrets @{ 'EntraExternalId:ClientId' = '<client-id>'; 'EntraExternalId:TenantId' = '<tenant-id>' }"

.NOTES
- Requires the .NET SDK.
- Relative paths resolve from the current directory.
#>
param(
    [Parameter(Mandatory)][string]$ProjectPath,
    [Parameter(Mandatory)][hashtable]$Secrets,
    [switch]$ShowSecrets
)

. "$PSScriptRoot\..\lib\Dotnet.Common.ps1"

return (Save-DotnetUserSecrets -ProjectPath $ProjectPath -Secrets $Secrets -Label (Get-DotnetProjectName $ProjectPath) -ShowSecrets:$ShowSecrets)
