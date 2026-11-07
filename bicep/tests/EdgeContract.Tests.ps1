BeforeAll {
    $script:bicep = (Resolve-Path "$PSScriptRoot\..").Path
}

Describe 'Low-cost edge Bicep contract' {
    It 'defaults to Standard and skips fixed-cost modules when origins are empty' {
        $json = az bicep build --stdout --file "$bicep\templates\platform-shared-edge-frontdoor.bicep"
        $LASTEXITCODE | Should -Be 0
        $template = ($json -join "`n") | ConvertFrom-Json
        $template.parameters.afdSku.defaultValue | Should -Be 'Standard_AzureFrontDoor'
        $template.parameters.wafRateLimitThreshold.defaultValue | Should -Be 300
        $template.parameters.origins.defaultValue | Should -BeNullOrEmpty
        $resources = if ($template.resources -is [array]) { $template.resources } else { $template.resources.PSObject.Properties.Value }
        $modules = @($resources | Where-Object { $_.type -eq 'Microsoft.Resources/deployments' -and $_.name -in @('afdName', 'wafName') })
        $modules.Count | Should -Be 2
        foreach ($module in $modules) { $module.condition | Should -Be "[variables('hasOrigins')]" }
        $template.outputs.resourceId.value | Should -Match "if\(variables\('hasOrigins'\)"
    }

    It 'uses custom rate limiting on Standard and keeps managed rules Premium-only' {
        $json = az bicep build --stdout --file "$bicep\modules\fdfp-frontdoorwafpolicy.bicep"
        $LASTEXITCODE | Should -Be 0
        $template = ($json -join "`n") | ConvertFrom-Json
        $template.parameters.sku.defaultValue | Should -Be 'Standard_AzureFrontDoor'
        $template.parameters.rateLimitThreshold.defaultValue | Should -Be 300
        $resources = if ($template.resources -is [array]) { $template.resources } else { $template.resources.PSObject.Properties.Value }
        $waf = $resources | Where-Object { $_.type -eq 'Microsoft.Network/frontdoorWebApplicationFirewallPolicies' }
        $waf.properties.managedRules.managedRuleSets | Should -Be "[if(equals(parameters('sku'), 'Premium_AzureFrontDoor'), createArray(variables('defaultRuleSet'), variables('botManagerRuleSet')), createArray())]"
        $template.parameters.mode.defaultValue | Should -Be 'Prevention'
        $template.variables.rateLimitRule.action | Should -Be 'Block'
        $template.variables.rateLimitRule.rateLimitDurationInMinutes | Should -Be 1
        $template.parameters.sku.allowedValues | Should -Contain 'Premium_AzureFrontDoor'
    }

    It 'compiles the low-cost edge parameter file' {
        $json = az bicep build-params --stdout --file "$bicep\variables\platform-shared-edge-frontdoor-plat.bicepparam"
        $LASTEXITCODE | Should -Be 0
        $compiled = ($json -join "`n") | ConvertFrom-Json
        $parameters = ($compiled.parametersJson | ConvertFrom-Json).parameters
        $parameters.afdSku.value | Should -Be 'Standard_AzureFrontDoor'
        $parameters.wafRateLimitThreshold.value | Should -Be 300
    }
}