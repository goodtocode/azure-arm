BeforeAll {
    . "$PSScriptRoot\..\lib\AzureSql.Common.ps1"
    $script:arguments = @{
        RuntimeName = 'product-api'
        RuntimeClientId = [guid]'11111111-1111-1111-1111-111111111111'
        MigrationName = 'product-migrations'
        MigrationClientId = [guid]'22222222-2222-2222-2222-222222222222'
    }
}

Describe 'Azure SQL contained principal bootstrap' {
    It 'uses explicit SIDs without Graph or password authentication' {
        $query = New-AzureSqlPrincipalBatch @arguments
        $query | Should -Match 'WITH SID = 0x11111111111111111111111111111111, TYPE = E'
        $query | Should -Not -Match 'EXTERNAL PROVIDER|PASSWORD|db_owner'
    }

    It 'converts client ID GUID byte order to the SQL binary SID' {
        $values = $arguments.Clone()
        $values.RuntimeClientId = [guid]'00001111-aaaa-2222-bbbb-3333cccc4444'
        New-AzureSqlPrincipalBatch @values | Should -Match 'WITH SID = 0x11110000AAAA2222BBBB3333CCCC4444'
    }

    It 'grants DML to both identities but DDL only to migration' {
        $query = New-AzureSqlPrincipalBatch @arguments
        $query | Should -Match 'ALTER ROLE \[db_datareader\] ADD MEMBER \[product-api\]'
        $query | Should -Match 'ALTER ROLE \[db_datawriter\] ADD MEMBER \[product-api\]'
        $query | Should -Match 'ALTER ROLE \[db_ddladmin\] ADD MEMBER \[product-migrations\]'
        $query | Should -Not -Match 'ALTER ROLE \[db_ddladmin\] ADD MEMBER \[product-api\]'
    }

    It 'guards existing users and elevated runtime permissions before granting roles' {
        $query = New-AzureSqlPrincipalBatch @arguments
        $query | Should -Match 'Existing SQL principal has a different identity'
        $query | Should -Match 'Identity already has a different SQL user name'
        $query | Should -Match 'Runtime SQL user already has non-runtime permissions'
        $query | Should -Match 'SET XACT_ABORT ON; BEGIN TRANSACTION;'
        $query | Should -Match 'COMMIT TRANSACTION;'
    }

    It 'quotes user names safely as identifiers and literals' {
        $values = $arguments.Clone()
        $values.RuntimeName = "api]O'Brien"
        $query = New-AzureSqlPrincipalBatch @values
        $query | Should -Match "CREATE USER \[api\]\]O'Brien\]"
        $query | Should -Match "N'api\]O''Brien'"
    }

    It 'rejects a shared runtime and migration identity' {
        $values = $arguments.Clone()
        $values.MigrationClientId = $values.RuntimeClientId
        { New-AzureSqlPrincipalBatch @values } | Should -Throw '*must be distinct*'
    }

    It 'rejects placeholder principal IDs before contacting Azure' {
        $values = $arguments.Clone()
        $values.RuntimeClientId = [guid]::Empty
        { New-AzureSqlPrincipalBatch @values } | Should -Throw '*placeholder*'
    }
}
