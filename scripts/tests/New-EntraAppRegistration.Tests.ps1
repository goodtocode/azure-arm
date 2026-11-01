BeforeAll {
    $path = Join-Path $PSScriptRoot '..\entra\New-EntraAppRegistration.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $wanted = 'ConvertTo-ScopeSpec', 'New-ScopeSpec', 'ConvertTo-RoleSpec', 'New-RoleSpec', 'ConvertTo-ClaimSpec', 'Get-MergedOptionalClaims', 'Get-MergedResourceAccess'

    # Definitions only: the script itself signs in to Entra, so run just its pure helper functions and lookup tables.
    $assignments = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -in '$knownText', '$knownRoles' }, $false)
    foreach ($a in $assignments) { Invoke-Expression $a.Extent.Text }
    $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in $wanted }, $false)
    foreach ($f in $functions) { Invoke-Expression $f.Extent.Text }
}

Describe 'Get-MergedOptionalClaims' {
    It 'adds missing claims and keeps existing ones' {
        $app = [pscustomobject]@{ OptionalClaims = [pscustomobject]@{ IdToken = @([pscustomobject]@{ Name = 'email' }); AccessToken = $null; Saml2Token = $null } }
        $merged = Get-MergedOptionalClaims $app @('email', 'upn') @('given_name')
        @($merged.idToken | ForEach-Object { $_.name }) | Should -Be @('email', 'upn')
        @($merged.accessToken | ForEach-Object { $_.name }) | Should -Be @('given_name')
    }
    It 'returns nothing when every claim is already present' {
        $app = [pscustomobject]@{ OptionalClaims = [pscustomobject]@{ IdToken = @([pscustomobject]@{ Name = 'email' }); AccessToken = @([pscustomobject]@{ Name = 'upn' }); Saml2Token = $null } }
        Get-MergedOptionalClaims $app @('email') @('upn') | Should -BeNullOrEmpty
    }
    It 'handles an app with no optional claims' {
        $app = [pscustomobject]@{ OptionalClaims = $null }
        $merged = Get-MergedOptionalClaims $app @('email') @()
        @($merged.idToken).Count | Should -Be 1
    }
}

Describe 'Get-MergedResourceAccess' {
    BeforeAll {
        $script:existing = [pscustomobject]@{ RequiredResourceAccess = @([pscustomobject]@{ ResourceAppId = 'other'; ResourceAccess = @([pscustomobject]@{ Id = '1'; Type = 'Scope' }) }) }
    }
    It 'keeps other resources and adds the wanted permissions' {
        $merged = Get-MergedResourceAccess $script:existing 'graph' @(@{ Id = 'a'; Type = 'Scope' }, @{ Id = 'b'; Type = 'Scope' })
        @($merged).Count | Should -Be 2
        ($merged | Where-Object { $_.ResourceAppId -eq 'other' }).ResourceAccess[0].Id | Should -Be '1'
        @(($merged | Where-Object { $_.ResourceAppId -eq 'graph' }).ResourceAccess | ForEach-Object { $_.Id }) | Should -Be @('a', 'b')
    }
    It 'returns nothing when everything is already granted' {
        $app = [pscustomobject]@{ RequiredResourceAccess = @([pscustomobject]@{ ResourceAppId = 'graph'; ResourceAccess = @([pscustomobject]@{ Id = 'a'; Type = 'Scope' }) }) }
        Get-MergedResourceAccess $app 'graph' @(@{ Id = 'a'; Type = 'Scope' }) | Should -BeNullOrEmpty
    }
    It 'handles an app with no resource access without errors' {
        $app = [pscustomobject]@{ RequiredResourceAccess = $null }
        $Error.Clear()
        $merged = Get-MergedResourceAccess $app 'graph' @(@{ Id = 'a'; Type = 'Scope' })
        @($merged).Count | Should -Be 1
        $Error.Count | Should -Be 0
    }
}

Describe 'spec builders' {
    It 'builds a scope with consent text for a known and an unknown value' {
        foreach ($value in 'assets.read', 'custom.thing') {
            $s = New-ScopeSpec $value
            $s.Value | Should -Be $value
            $s.Id | Should -Not -BeNullOrEmpty
            $s.AdminConsentDescription | Should -Not -BeNullOrEmpty
        }
    }
    It 'builds an application role' {
        (New-RoleSpec 'Asset.Automation' 'Application').AllowedMemberTypes | Should -Contain 'Application'
    }
    It 'round-trips an existing role' {
        $r = [pscustomobject]@{ Id = [guid]::NewGuid(); Value = 'X'; DisplayName = 'X'; Description = 'd'; IsEnabled = $true; AllowedMemberTypes = @('User') }
        (ConvertTo-RoleSpec $r).Value | Should -Be 'X'
    }
}
