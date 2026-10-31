BeforeDiscovery {
    $script:HasDotnet = [bool](Get-Command dotnet -ErrorAction SilentlyContinue)
}

BeforeAll {
    . "$PSScriptRoot\..\lib\Dotnet.Common.ps1"
    if (Get-Command dotnet -ErrorAction SilentlyContinue) {
        $script:Root = Join-Path ([IO.Path]::GetTempPath()) "pester-dotnet-$([guid]::NewGuid().ToString('N'))"
        $script:Project = Join-Path $script:Root 'UtProj'
        dotnet new console -n UtProj -o $script:Project | Out-Null
        $script:ProjectFile = Join-Path $script:Project 'UtProj.csproj'
    }
}

AfterAll {
    if ($script:ProjectFile) { dotnet user-secrets clear --project $script:ProjectFile | Out-Null }
    if ($script:Root -and (Test-Path $script:Root)) { Remove-Item $script:Root -Recurse -Force }
}

Describe 'Get-DotnetProjectName' {
    It 'strips the folder and the .csproj extension' {
        Get-DotnetProjectName 'src\Presentation.Web\Presentation.Web.csproj' | Should -Be 'Presentation.Web'
    }
    It 'returns the folder name for a folder path' {
        Get-DotnetProjectName './src/Presentation.Api' | Should -Be 'Presentation.Api'
    }
    It 'returns an empty string for an empty path' {
        Get-DotnetProjectName '' | Should -Be ''
    }
}

Describe 'user-secrets helpers' -Skip:(-not $script:HasDotnet) {
    It 'sets secrets using a project folder' {
        $result = @(Set-DotnetUserSecrets -ProjectPath $script:Project -Secrets @{ 'A:B' = '1'; 'C:D' = 'x = y' } 6>$null)[-1]
        $result | Should -BeTrue
    }
    It 'sets secrets using the .csproj path' {
        $result = @(Set-DotnetUserSecrets -ProjectPath $script:ProjectFile -Secrets @{ 'A:B' = '1' } 6>$null)[-1]
        $result | Should -BeTrue
    }
    It 'reads secrets back, including values that contain " = "' {
        $secrets = Get-DotnetUserSecrets -ProjectPath $script:Project
        $secrets['A:B'] | Should -Be '1'
        $secrets['C:D'] | Should -Be 'x = y'
    }
    It 'returns false for a path that does not exist' {
        $result = @(Set-DotnetUserSecrets -ProjectPath (Join-Path $script:Root 'missing') -Secrets @{ 'A:B' = '1' } 3>$null 6>$null)[-1]
        $result | Should -BeFalse
    }
    It 'prints secret values once when they cannot be stored' {
        $captured = Save-DotnetUserSecrets -ProjectPath (Join-Path $script:Root 'missing') -Secrets @{ 'My:ClientSecret' = 'abc' } -Label 'T' 6>&1 3>&1
        ($captured | Out-String) | Should -Match 'My:ClientSecret = abc'
        @($captured)[-1] | Should -BeFalse
    }
    It 'does not print values that are not secrets' {
        $captured = Save-DotnetUserSecrets -ProjectPath (Join-Path $script:Root 'missing') -Secrets @{ 'My:ClientId' = 'abc' } -Label 'T' 6>&1 3>&1
        ($captured | Out-String) | Should -Not -Match 'My:ClientId = abc'
    }
}
