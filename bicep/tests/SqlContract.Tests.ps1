BeforeAll {
    $script:bicep = (Resolve-Path "$PSScriptRoot\..").Path
}

Describe 'Digital product SQL Bicep contract' {
    It 'compiles owned and referenced Entra-only server choices' {
        foreach ($file in @(
            "$bicep\variables\workload-digitalproduct-standalone-dev.bicepparam",
            "$bicep\variables\workload-digitalproduct-standalone-test.bicepparam"
        )) {
            $text = az bicep build-params --stdout --file $file 2>&1 | Out-String
            $LASTEXITCODE | Should -Be 0 -Because $text
        }
    }

    It 'rejects password authentication and incomplete server references' {
        foreach ($file in @('sql-invalid-entra.bicepparam', 'sql-invalid-existing.bicepparam', 'sql-invalid-password.bicepparam')) {
            $text = az bicep build-params --stdout --file "$PSScriptRoot\fixtures\$file" 2>&1 | Out-String
            $LASTEXITCODE | Should -Not -Be 0 -Because "Invalid configuration must fail: $text"
        }

    }

    It 'enforces Entra-only without a deployment override or SQL administrator password' {
        $text = az bicep build --stdout --file "$bicep\modules\sql-sqlserver.bicep"
        $LASTEXITCODE | Should -Be 0
        $template = $text -join "`n" | ConvertFrom-Json
        $server = $template.resources.sqlServer
        $server.type | Should -Be 'Microsoft.Sql/servers'
        $server.properties.administrators.azureADOnlyAuthentication | Should -BeTrue
        $server.properties.PSObject.Properties.Name | Should -Not -Contain 'administratorLoginPassword'
        $template.parameters.PSObject.Properties.Name | Should -Not -Contain 'entraOnlyAuthentication'
        $template.parameters.PSObject.Properties.Name | Should -Not -Contain 'adminPassword'
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
