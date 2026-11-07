# Shared helpers for .NET user-secrets. Dot-source it: . "$PSScriptRoot\..\lib\Dotnet.Common.ps1"

function Get-DotnetProjectName {
    param([string]$ProjectPath)
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { return '' }
    $leaf = Split-Path $ProjectPath.TrimEnd('\', '/') -Leaf
    if ($leaf -like '*.csproj') { $leaf = [IO.Path]::GetFileNameWithoutExtension($leaf) }
    return $leaf
}

# Resolves a project folder or .csproj path to the .csproj file, or $null with a warning.
function Resolve-DotnetProjectFile {
    param([string]$ProjectPath)
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { return $null }
    $resolved = Resolve-Path -Path $ProjectPath -ErrorAction SilentlyContinue
    if (-not $resolved) {
        Write-Warning "*** Project path '$ProjectPath' not found. ***"
        return $null
    }
    $target = $resolved.Path
    if ((Test-Path $target -PathType Leaf) -and $target.EndsWith('.csproj', [System.StringComparison]::OrdinalIgnoreCase)) { return $target }
    if (Test-Path $target -PathType Container) {
        $project = Get-ChildItem -Path $target -Filter '*.csproj' -File | Select-Object -First 1
        if ($project) { return $project.FullName }
    }
    Write-Warning "*** No .csproj found at '$target'. ***"
    return $null
}

# Returns $true only when every value was written to the project's user-secrets.
function Set-DotnetUserSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets)
    $projectFile = Resolve-DotnetProjectFile $ProjectPath
    if (-not $projectFile) { return $false }

    Write-Host "Setting .NET user-secrets for project: $projectFile"
    dotnet user-secrets init --project "$projectFile" | Out-Null
    if ($LASTEXITCODE -ne 0) { return $false }
    $Secrets | ConvertTo-Json -Depth 10 -Compress | dotnet user-secrets set --project "$projectFile" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Failed to persist user-secrets. Values are not logged.'
        return $false
    }
    return $true
}

# Returns the project's user-secrets as a hashtable (empty when none or the project is not found).
function Get-DotnetUserSecrets {
    param([string]$ProjectPath)
    $secrets = @{}
    $projectFile = Resolve-DotnetProjectFile $ProjectPath
    if (-not $projectFile) { return $secrets }
    $secretId = (dotnet msbuild "$projectFile" -getProperty:UserSecretsId -nologo | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve the project user-secrets ID.' }
    if (-not $secretId) { return $secrets }
    if ($secretId -match '[\\/]' -or $secretId -in @('.', '..')) { throw 'Invalid project user-secrets ID.' }
    $root = if ($IsWindows) { Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Microsoft/UserSecrets' } else { Join-Path $HOME '.microsoft/usersecrets' }
    $path = Join-Path (Join-Path $root $secretId) 'secrets.json'
    if (-not (Test-Path -LiteralPath $path)) { return $secrets }
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
}

function Show-UnstoredSecrets {
    param([hashtable]$Secrets)
    foreach ($key in $Secrets.Keys) {
        if ($key -match 'Secret|Password' -and -not [string]::IsNullOrWhiteSpace([string]$Secrets[$key])) {
            Write-Host "  $key = $($Secrets[$key])" -ForegroundColor Yellow
        }
    }
}

# Stores values in user-secrets without a credential-display fallback.
function Save-DotnetUserSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets, [string]$Label = 'Project', [switch]$ShowSecrets)
    $stored = Set-DotnetUserSecrets -ProjectPath $ProjectPath -Secrets $Secrets
    if (-not $stored) {
        throw "$Label secrets were not stored. Values are not printed; fix storage and rerun."
    }
    elseif ($ShowSecrets) {
        throw 'Secret display is disabled. Use an approved secret store.'
    }
    return $stored
}
