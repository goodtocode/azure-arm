BeforeAll {
    $path = Join-Path $PSScriptRoot '..\entra\New-EntraAppRegistration.ps1'
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$null)
    $wanted = 'ConvertTo-ScopeSpec', 'New-ScopeSpec', 'ConvertTo-RoleSpec', 'New-RoleSpec', 'Assert-StrictApplicationRoles', 'ConvertTo-ClaimSpec', 'Get-MergedOptionalClaims', 'Get-MergedResourceAccess', 'Get-ApiApplicationRoles', 'Get-MissingApiRoleAssignments'

    # Definitions only: the script itself signs in to Entra, so run just its pure helper functions and lookup tables.
    $assignments = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -in '$knownText', '$knownRoles' }, $false)
    foreach ($a in $assignments) { Invoke-Expression $a.Extent.Text }
    $functions = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in $wanted }, $false)
    foreach ($f in $functions) { Invoke-Expression $f.Extent.Text }

    $script:identifierUriAssignment = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and $node.Left.Extent.Text -eq '$identifierUri' }, $false).Extent.Text
    $script:claimDefaults = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.IfStatementAst] -and
            ($node.Extent.Text.StartsWith("if (-not `$PSBoundParameters.ContainsKey('IdTokenClaims'))") -or
             $node.Extent.Text.StartsWith("if (-not `$PSBoundParameters.ContainsKey('AccessTokenClaims'))"))
    }, $false))
    function Get-ClaimDefaultCounts {
        param([string]$Type, [string[]]$IdTokenClaims, [string[]]$AccessTokenClaims)
        Set-StrictMode -Version Latest
        foreach ($statement in $script:claimDefaults) { Invoke-Expression $statement.Extent.Text }
        return @($IdTokenClaims.Count, $AccessTokenClaims.Count)
    }
}

Describe 'registration defaults under strict mode' {
    It 'handles an empty identifier URI list' {
        Set-StrictMode -Version Latest
        $app = [pscustomobject]@{ IdentifierUris = @() }
        Invoke-Expression $script:identifierUriAssignment
        $identifierUri | Should -BeNullOrEmpty
    }
    It 'preserves claim arrays for <type>' -TestCases @(
        @{ type = 'Api'; idCount = 0; accessCount = 4 }
        @{ type = 'Web'; idCount = 7; accessCount = 0 }
        @{ type = 'E2E'; idCount = 0; accessCount = 0 }
    ) {
        param($type, $idCount, $accessCount)
        $counts = Get-ClaimDefaultCounts -Type $type
        $counts[0] | Should -Be $idCount
        $counts[1] | Should -Be $accessCount
    }
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

Describe 'strict application roles' {
    It 'accepts a missing role or an enabled application-only role' {
        { Assert-StrictApplicationRoles @() @('Product.Install') @() } | Should -Not -Throw
        $role = @{ Value = 'Product.Install'; IsEnabled = $true; AllowedMemberTypes = @('Application') }
        { Assert-StrictApplicationRoles @($role) @('Product.Install') @() } | Should -Not -Throw
    }

    It 'rejects roles that permit users or are disabled' {
        $role = @{ Value = 'Product.Install'; IsEnabled = $true; AllowedMemberTypes = @('Application', 'User') }
        { Assert-StrictApplicationRoles @($role) @('Product.Install') @() } | Should -Throw
        $role.AllowedMemberTypes = @('Application')
        $role.IsEnabled = $false
        { Assert-StrictApplicationRoles @($role) @('Product.Install') @() } | Should -Throw
        { Assert-StrictApplicationRoles @() @('Product.Install') @('Product.Install') } | Should -Throw
    }

    Describe 'shared automation application roles' {
        BeforeEach {
            $script:api = [pscustomobject]@{
                AppRoles = @(
                    [pscustomobject]@{ Id = 'automation'; Value = 'Asset.Automation'; IsEnabled = $true; AllowedMemberTypes = @('Application') }
                    [pscustomobject]@{ Id = 'install'; Value = 'Product.Install'; IsEnabled = $true; AllowedMemberTypes = @('Application') }
                )
            }
        }

        It 'resolves both roles and preserves unrelated resource permissions' {
            $roles = @(Get-ApiApplicationRoles $api @('Asset.Automation', 'Product.Install') 'api')
            $roles.Value | Should -Be @('Asset.Automation', 'Product.Install')
            $app = [pscustomobject]@{ RequiredResourceAccess = @(
                [pscustomobject]@{ ResourceAppId = 'other'; ResourceAccess = @([pscustomobject]@{ Id = 'other-id'; Type = 'Scope' }) }
                [pscustomobject]@{ ResourceAppId = 'api'; ResourceAccess = @([pscustomobject]@{ Id = 'automation'; Type = 'Role' }) }
            ) }
            $wanted = @($roles | ForEach-Object { @{ Id = $_.Id; Type = 'Role' } })
            $merged = Get-MergedResourceAccess $app 'api' $wanted
            @(($merged | Where-Object ResourceAppId -EQ 'api').ResourceAccess.Id) | Should -Be @('automation', 'install')
            @(($merged | Where-Object ResourceAppId -EQ 'other').ResourceAccess.Id) | Should -Be @('other-id')
        }

        It 'adds only missing assignments and is idempotent on rerun' {
            $roles = @(Get-ApiApplicationRoles $api @('Asset.Automation', 'Product.Install') 'api')
            $existing = @([pscustomobject]@{ AppRoleId = 'automation'; ResourceId = 'api-sp' })
            @(Get-MissingApiRoleAssignments $roles $existing 'api-sp').Value | Should -Be @('Product.Install')
            $existing += [pscustomobject]@{ AppRoleId = 'install'; ResourceId = 'api-sp' }
            @(Get-MissingApiRoleAssignments $roles $existing 'api-sp').Count | Should -Be 0
        }

        It 'grants both roles to the same service principal without duplicating them' {
            $roleAssignmentBlock = $ast.Find({
                param($node)
                $node -is [System.Management.Automation.Language.IfStatementAst] -and
                $node.Extent.Text.StartsWith("if (`$Type -eq 'E2E')") -and
                $node.Extent.Text.Contains('New-MgServicePrincipalAppRoleAssignment')
            }, $true)
            $Type = 'E2E'
            $ApiAppId = 'api'
            $roles = @(Get-ApiApplicationRoles $api @('Asset.Automation', 'Product.Install') 'api')
            $sp = [pscustomobject]@{ Id = 'automation-sp' }
            $script:assignedRoles = @()
            $script:grantCount = 0
            function Get-OrNew-ServicePrincipal { param($AppId) return [pscustomobject]@{ Id = 'api-sp' } }
            function Get-MgServicePrincipalAppRoleAssignment {
                param($ServicePrincipalId, [switch]$All)
                return $script:assignedRoles
            }
            function New-MgServicePrincipalAppRoleAssignment {
                param($ServicePrincipalId, $PrincipalId, $ResourceId, $AppRoleId)
                if ($ServicePrincipalId -ne 'automation-sp' -or $PrincipalId -ne 'automation-sp') {
                    throw 'Roles must be assigned to the existing automation principal.'
                }
                $script:grantCount++
                $script:assignedRoles += [pscustomobject]@{ AppRoleId = $AppRoleId; ResourceId = $ResourceId }
            }

            Invoke-Expression $roleAssignmentBlock.Extent.Text
            Invoke-Expression $roleAssignmentBlock.Extent.Text
            $script:grantCount | Should -Be 2
            @($script:assignedRoles.AppRoleId) | Should -Be @('automation', 'install')
        }

        It 'fails if a requested role is missing or disabled' {
            { Get-ApiApplicationRoles $api @('Asset.Automation', 'missing') 'api' } | Should -Throw '*missing*'
            $api.AppRoles[1].IsEnabled = $false
            { Get-ApiApplicationRoles $api @('Asset.Automation', 'Product.Install') 'api' } | Should -Throw '*Product.Install*'
        }

        It 'requires E2E when extra automation roles are requested' {
            $scriptPath = Join-Path $PSScriptRoot '..\New-EntraDotnetSolution.ps1'
            { & $scriptPath -EntraInstanceUrl 'https://example.invalid' -TenantId 'synthetic' -ApiAppRegistrationName 'api' -E2EAdditionalApiRoles 'Product.Install' } |
                Should -Throw '*require -IncludeE2E*'
        }

        It 'requests both roles on the API and the existing E2E registration' {
            $scriptPath = Join-Path $PSScriptRoot '..\New-EntraDotnetSolution.ps1'
            $solutionAst = [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$null)
            $apiArgs = @{}
            $E2EAdditionalApiRoles = @('Product.Install')
            $apiRoleMapping = $solutionAst.Find({
                param($node)
                $node -is [System.Management.Automation.Language.IfStatementAst] -and
                $node.Extent.Text.StartsWith('if ($E2EAdditionalApiRoles.Count -gt 0)') -and
                $node.Extent.Text.Contains('$apiArgs.ApplicationRoles')
            }, $true)
            Invoke-Expression $apiRoleMapping.Extent.Text
            $apiArgs.ApplicationRoles | Should -Be @('Asset.Automation', 'Product.Install')
            $apiArgs.StrictApplicationRoles | Should -Be @('Product.Install')

            $e2eArgsAssignment = $solutionAst.Find({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left.Extent.Text -eq '$e2eArgs'
            }, $true)
            $TenantId = 'synthetic'
            $E2EAppRegistrationName = 'existing-e2e'
            $E2EProjectPath = 'existing-project'
            $api = [pscustomobject]@{ AppId = 'api' }
            function Get-DotnetProjectName { param($ProjectPath) return $ProjectPath }
            Invoke-Expression $e2eArgsAssignment.Extent.Text
            $e2eArgs.AppRegistrationName | Should -Be 'existing-e2e'
            $e2eArgs.ApiRole | Should -Be @('Asset.Automation', 'Product.Install')
        }
    }
}
