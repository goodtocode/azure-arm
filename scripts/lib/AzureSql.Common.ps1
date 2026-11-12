Set-StrictMode -Version Latest

function New-AzureSqlPrincipalBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateLength(1, 128)][string]$RuntimeName,
        [Parameter(Mandatory)][guid]$RuntimeClientId,
        [Parameter(Mandatory)][ValidateLength(1, 128)][string]$MigrationName,
        [Parameter(Mandatory)][guid]$MigrationClientId
    )

    if ($RuntimeClientId -eq [guid]::Empty -or $MigrationClientId -eq [guid]::Empty) {
        throw 'SQL service-principal client IDs must not be empty or placeholder GUIDs.'
    }
    if ($RuntimeClientId -eq $MigrationClientId -or $RuntimeName -eq $MigrationName) {
        throw 'Runtime and migration identities must be distinct.'
    }

    $statements = [System.Collections.Generic.List[string]]::new()
    $statements.Add('SET XACT_ABORT ON; BEGIN TRANSACTION;')
    foreach ($principal in @(
        @{ Name = $RuntimeName; Id = $RuntimeClientId; Runtime = $true },
        @{ Name = $MigrationName; Id = $MigrationClientId; Runtime = $false }
    )) {
        $identifier = '[' + $principal.Name.Replace(']', ']]') + ']'
        $literal = "N'" + $principal.Name.Replace("'", "''") + "'"
        $sid = '0x' + [Convert]::ToHexString($principal.Id.ToByteArray())
        $statements.Add(@"
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = $literal AND (sid <> $sid OR type <> 'E'))
    THROW 51000, 'Existing SQL principal has a different identity or type; no grants were changed.', 1;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE sid = $sid AND name <> $literal)
    THROW 51000, 'Identity already has a different SQL user name; explicitly reconcile before bootstrap.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = $literal)
    CREATE USER $identifier WITH SID = $sid, TYPE = E;
"@)
        if ($principal.Runtime) {
            $statements.Add(@"
IF EXISTS (
    SELECT 1 FROM sys.database_role_members m
    JOIN sys.database_principals r ON r.principal_id = m.role_principal_id
    WHERE m.member_principal_id = DATABASE_PRINCIPAL_ID($literal)
      AND r.name NOT IN ('db_datareader', 'db_datawriter')
) OR EXISTS (
    SELECT 1 FROM sys.database_permissions
    WHERE grantee_principal_id = DATABASE_PRINCIPAL_ID($literal)
      AND (state = 'W' OR (state = 'G' AND permission_name NOT IN ('CONNECT', 'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'EXECUTE')))
)
    THROW 51000, 'Runtime SQL user already has non-runtime permissions; explicitly reconcile before bootstrap.', 1;
"@)
        }
        $roles = @('db_datareader', 'db_datawriter')
        if (-not $principal.Runtime) { $roles += 'db_ddladmin' }
        foreach ($role in $roles) {
            $statements.Add("IF IS_ROLEMEMBER(N'$role', $literal) <> 1 ALTER ROLE [$role] ADD MEMBER $identifier;")
        }
    }
    $statements.Add('COMMIT TRANSACTION;')
    return $statements -join "`n"
}
