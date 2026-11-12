BeforeAll {
    $script:bicep = (Resolve-Path "$PSScriptRoot\..").Path
}

Describe 'Digital product SQL Bicep contract' {
    It 'compiles owned and referenced authentication choices' {
        $names = @('SQL_ENTRA_ADMIN_GROUP_OBJECT_ID', 'AZURE_TENANT_ID')
        $saved = @{}
        foreach ($name in $names) {
            $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, '00000000-0000-0000-0000-000000000000', 'Process')
        }
        try {
            foreach ($file in @(
                "$bicep\variables\workload-digitalproduct-standalone-dev.bicepparam",
                "$bicep\variables\workload-digitalproduct-standalone-test.bicepparam",
                "$PSScriptRoot\fixtures\sql-valid-password.bicepparam"
            )) {
                $text = az bicep build-params --stdout --file $file 2>&1 | Out-String
                $LASTEXITCODE | Should -Be 0 -Because $text
            }
        }
        finally { foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') } }
    }

    It 'rejects malformed authentication and incomplete server references' {
        foreach ($file in @('sql-invalid-entra.bicepparam', 'sql-invalid-existing.bicepparam', 'sql-invalid-password.bicepparam')) {
            $text = az bicep build-params --stdout --file "$PSScriptRoot\fixtures\$file" 2>&1 | Out-String
            $LASTEXITCODE | Should -Not -Be 0 -Because "Invalid configuration must fail: $text"
        }

    }

    It 'limits authentication properties to creation and keeps the password secure' {
        $text = az bicep build --stdout --file "$bicep\modules\sql-sqlserver.bicep"
        $LASTEXITCODE | Should -Be 0
        $template = $text -join "`n" | ConvertFrom-Json
        $server = $template.resources.sqlServer
        $server.type | Should -Be 'Microsoft.Sql/servers'
        $server.properties | Should -Match "if\(not\(parameters\('createServer'\)\), createObject\(\)"
        $server.properties | Should -Match "equals\(parameters\('authentication'\), 'SqlAuth'\)"
        $server.properties | Should -Match "'azureADOnlyAuthentication', true\(\)"
        $template.parameters.sqlAdministratorPassword.type | Should -Be 'securestring'
        $template.parameters.authentication.allowedValues | Should -Contain 'SqlAuth'
        $template.parameters.authentication.allowedValues | Should -Contain 'EntraOnly'
        $template.parameters.PSObject.Properties.Name | Should -Not -Contain 'entraOnlyAuthentication'
        $template.parameters.PSObject.Properties.Name | Should -Not -Contain 'adminPassword'
    }

    It 'reconciles the Entra administrator only for existing workload-owned servers' {
        $text = az bicep build --stdout --file "$bicep\modules\sql-sqlserver.bicep"
        $LASTEXITCODE | Should -Be 0
        $template = $text -join "`n" | ConvertFrom-Json
        $administrator = $template.resources.sqlServerEntraAdministrator
        $administrator.type | Should -Be 'Microsoft.Sql/servers/administrators'
        $administrator.condition | Should -Be "[and(not(parameters('createServer')), equals(parameters('authentication'), 'EntraOnly'))]"
        $administrator.properties.sid | Should -Be "[parameters('entraAdministrator').objectId]"
        (Get-Content "$bicep\modules\sqldb-workloaddatabase.bicep" -Raw) | Should -Match "module serverModule 'sql-sqlserver\.bicep' = if \(!existing\)"
    }

    It 'emits the same non-secret deployment output keys in both network compositions' {
        foreach ($file in @('workload-digitalproduct.bicep', 'workload-digitalproduct-zerotrust.bicep')) {
            $text = az bicep build --stdout --file "$bicep\templates\$file" 2>&1
            $LASTEXITCODE | Should -Be 0
            $template = ($text | Where-Object { $_ -is [string] }) -join "`n" | ConvertFrom-Json
            foreach ($name in @('apiAppName', 'webAppName', 'apiEndpoint', 'webEndpoint', 'applicationInsightsResourceId', 'sqlServerHost', 'sqlDatabaseName', 'sqlDatabaseResourceId', 'sqlServerKind', 'apiPrincipalId', 'apiManagedIdentityClientId')) {
                $template.outputs.PSObject.Properties.Name | Should -Contain $name
            }
            $template.outputs.PSObject.Properties.Name | Should -Not -Contain 'adminPassword'
        }
    }
}
