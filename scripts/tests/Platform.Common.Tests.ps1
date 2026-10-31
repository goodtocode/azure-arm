BeforeAll {
    . "$PSScriptRoot\..\lib\Platform.Common.ps1"
}

Describe 'Get-BicepParamValue' {
    BeforeAll {
        $script:file = Join-Path $TestDrive 'sample.bicepparam'
        Set-Content $script:file "using '../templates/x.bicep'`nvar regionIac = 'wus2'`nparam instanceName = 'abc'`nvar notQuoted = 5"
    }
    It 'reads a var value' { Get-BicepParamValue -File $script:file -Name 'regionIac' | Should -Be 'wus2' }
    It 'reads a param value' { Get-BicepParamValue -File $script:file -Name 'instanceName' | Should -Be 'abc' }
    It 'throws when the name is missing' { { Get-BicepParamValue -File $script:file -Name 'missing' } | Should -Throw }
    It 'throws when the file is missing' { { Get-BicepParamValue -File (Join-Path $TestDrive 'nope.bicepparam') -Name 'x' } | Should -Throw }
}

Describe 'Get-BicepRoot' {
    It 'returns bicep/ in the template repo layout' {
        $lib = Join-Path $TestDrive 'repo\scripts\lib'
        New-Item -ItemType Directory -Path $lib, (Join-Path $TestDrive 'repo\bicep\templates') -Force | Out-Null
        Get-BicepRoot -LibRoot $lib | Should -Be (Join-Path $TestDrive 'repo\bicep')
    }
    It 'returns the .azure folder in the consumer layout' {
        $lib = Join-Path $TestDrive 'consumer\.azure\scripts\lib'
        New-Item -ItemType Directory -Path $lib, (Join-Path $TestDrive 'consumer\.azure\templates') -Force | Out-Null
        Get-BicepRoot -LibRoot $lib | Should -Be (Join-Path $TestDrive 'consumer\.azure')
    }
}
