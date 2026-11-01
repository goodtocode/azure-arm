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
    foreach ($key in $Secrets.Keys) {
        dotnet user-secrets set "$key" "$($Secrets[$key])" --project "$projectFile" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "*** Failed to set '$key' in user-secrets. ***"
            return $false
        }
        Write-Host "  Set: $key"
    }
    return $true
}

# Returns the project's user-secrets as a hashtable (empty when none or the project is not found).
function Get-DotnetUserSecrets {
    param([string]$ProjectPath)
    $secrets = @{}
    $projectFile = Resolve-DotnetProjectFile $ProjectPath
    if (-not $projectFile) { return $secrets }
    foreach ($line in @(dotnet user-secrets list --project "$projectFile" 2>$null)) {
        $i = "$line".IndexOf(' = ')
        if ($i -gt 0) { $secrets["$line".Substring(0, $i).Trim()] = "$line".Substring($i + 3) }
    }
    return $secrets
}

function Show-UnstoredSecrets {
    param([hashtable]$Secrets)
    foreach ($key in $Secrets.Keys) {
        if ($key -match 'Secret|Password' -and -not [string]::IsNullOrWhiteSpace([string]$Secrets[$key])) {
            Write-Host "  $key = $($Secrets[$key])" -ForegroundColor Yellow
        }
    }
}

# Stores the values in user-secrets, or prints the secret ones once when that is not possible.
function Save-DotnetUserSecrets {
    param([string]$ProjectPath, [hashtable]$Secrets, [string]$Label = 'Project', [switch]$ShowSecrets)
    $stored = Set-DotnetUserSecrets -ProjectPath $ProjectPath -Secrets $Secrets
    if (-not $stored) {
        Write-Warning "*** $Label secrets were not stored. Secret values are shown only once below; copy them now. ***"
        Show-UnstoredSecrets -Secrets $Secrets
    }
    elseif ($ShowSecrets) {
        Write-Host "$Label secrets (shown once, for CI or Key Vault):" -ForegroundColor Yellow
        Show-UnstoredSecrets -Secrets $Secrets
    }
    return $stored
}
