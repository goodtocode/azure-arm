BeforeDiscovery {
    $scriptsRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Scripts = @(Get-ChildItem $scriptsRoot -Recurse -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\(tests|lib)\\' } | ForEach-Object {
        @{ Name = $_.FullName.Substring($scriptsRoot.Length + 1); Path = $_.FullName }
    })
}

Describe 'script conventions' {
    It '<Name> parses without errors' -ForEach $script:Scripts {
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }
    It '<Name> has a synopsis and at least one example' -ForEach $script:Scripts {
        $help = Get-Help $Path
        $help.Synopsis | Should -Not -BeNullOrEmpty
        $help.Synopsis | Should -Not -Match '^\s*$'
        @($help.examples.example).Count | Should -BeGreaterThan 0
    }
}
