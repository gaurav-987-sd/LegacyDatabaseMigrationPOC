<#
.SYNOPSIS
    Creates and migrates the SQL Server and/or PostgreSQL database for LegacyDatabaseMigrationPOC.

.DESCRIPTION
    Default mode builds the project and applies the EF6 code-first migrations of each selected
    provider with ef6.exe: the database is created when missing, pending migrations are applied
    and the seed (Migrations\SeedData.cs) runs. Safe to re-run.

    -GenerateScripts  Regenerates Database\Scripts\<Provider>\Migrations.sql: the SQL that takes an
                      empty database to the latest migration. Nothing is applied. Run it after
                      adding a migration and commit the result.

    -ApplyScripts     Creates the database when missing and runs Migrations.sql followed by
                      SeedData.sql with sqlcmd / psql. Needs no build and no Visual Studio.

.PARAMETER Provider
    SqlServer, PostgreSql or All (default).
.PARAMETER DatabaseName
    Overrides the database name taken from Web.config, for both providers.
.PARAMETER SkipBuild
    Use the existing bin\ output instead of building first.
.PARAMETER Configuration
    Build configuration, Debug by default.

.EXAMPLE
    .\Database\Setup-Database.ps1                            # create/migrate/seed both databases
    .\Database\Setup-Database.ps1 -Provider PostgreSql       # PostgreSQL only
    .\Database\Setup-Database.ps1 -GenerateScripts           # refresh the .sql files
    .\Database\Setup-Database.ps1 -ApplyScripts -DatabaseName LegacyDatabaseMigrationPOC_copy
#>
[CmdletBinding()]
param(
    [ValidateSet('SqlServer', 'PostgreSql', 'All')]
    [string]$Provider = 'All',
    [switch]$GenerateScripts,
    [switch]$ApplyScripts,
    [string]$DatabaseName,
    [switch]$SkipBuild,
    [string]$Configuration = 'Debug'
)

$ErrorActionPreference = 'Stop'

if ($GenerateScripts -and $ApplyScripts) {
    throw 'Use either -GenerateScripts or -ApplyScripts, not both.'
}

$projectDir = Split-Path -Parent $PSScriptRoot
$scriptsDir = Join-Path $PSScriptRoot 'Scripts'
$webConfig  = Join-Path $projectDir 'Web.config'
$assembly   = Join-Path $projectDir 'bin\LegacyDatabaseMigrationPOC.dll'
$ef6        = Join-Path $projectDir 'packages\EntityFramework.6.5.2\tools\net45\any\ef6.exe'

$providers = @{
    SqlServer  = @{
        ConnectionName   = 'SqlServerConnection'
        Invariant        = 'System.Data.SqlClient'
        MigrationsConfig = 'LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration'
    }
    PostgreSql = @{
        ConnectionName   = 'PostgresConnection'
        Invariant        = 'Npgsql'
        MigrationsConfig = 'LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration'
    }
}

if ($Provider -eq 'All') { $selected = @('SqlServer', 'PostgreSql') } else { $selected = @($Provider) }

# ---------------------------------------------------------------------------------------------
# Connection string helpers
# ---------------------------------------------------------------------------------------------

# Environment variable first, Web.config second - the same precedence the application uses
# (Data\DatabaseProvider.cs), so the script always targets the database the application would.
function Get-ConnectionString([string]$name) {
    $fromEnvironment = [Environment]::GetEnvironmentVariable($name)
    if (-not [string]::IsNullOrWhiteSpace($fromEnvironment)) {
        Write-Host "   using environment variable '$name'"
        return $fromEnvironment
    }

    [xml]$xml = Get-Content -LiteralPath $webConfig
    $node = $xml.configuration.connectionStrings.add | Where-Object { $_.name -eq $name }
    if (-not $node) { throw "Connection string '$name' not found in the environment or in $webConfig." }
    return [string]$node.connectionString
}

# Plain "key=value;" parsing. (DbConnectionStringBuilder is avoided on purpose: PowerShell treats it
# as a dictionary, so "$builder.ConnectionString = ..." adds a key instead of setting the property.)
function Get-ConnectionParts([string]$connectionString) {
    $parts = @{}
    foreach ($segment in ($connectionString -split ';')) {
        $index = $segment.IndexOf('=')
        if ($index -lt 0) { continue }
        $parts[$segment.Substring(0, $index).Trim().ToLowerInvariant()] = $segment.Substring($index + 1).Trim()
    }
    return $parts
}

function Get-FirstValue($parts, [string[]]$keys) {
    foreach ($key in $keys) {
        if ($parts.ContainsKey($key) -and $parts[$key]) { return $parts[$key] }
    }
    return $null
}

function Get-DatabaseName($parts) {
    $name = Get-FirstValue $parts @('database', 'initial catalog')
    if (-not $name) { throw 'Connection string has no Database / Initial Catalog.' }
    return $name
}

function Set-DatabaseName([string]$connectionString, [string]$name) {
    $segments = @()
    foreach ($segment in ($connectionString -split ';')) {
        if (-not $segment.Trim()) { continue }
        $index = $segment.IndexOf('=')
        $key = ''
        if ($index -ge 0) { $key = $segment.Substring(0, $index).Trim() }
        if ($key -in @('Database', 'Initial Catalog')) { $segments += "$key=$name" } else { $segments += $segment.Trim() }
    }
    return ($segments -join ';')
}

function Resolve-Connection([string]$providerName) {
    $info = $providers[$providerName]
    $connectionString = Get-ConnectionString $info.ConnectionName
    if ($DatabaseName) { $connectionString = Set-DatabaseName $connectionString $DatabaseName }
    return @{
        Name             = $providerName
        Info             = $info
        ConnectionString = $connectionString
        Parts            = (Get-ConnectionParts $connectionString)
    }
}

# ---------------------------------------------------------------------------------------------
# Build + ef6.exe
# ---------------------------------------------------------------------------------------------

function Invoke-Build {
    if ($SkipBuild) { return }

    $msbuild = Get-Command msbuild.exe -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source
    if (-not $msbuild) {
        $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
        if (Test-Path $vswhere) {
            $msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
        }
    }
    if (-not $msbuild) { throw 'MSBuild not found. Install Visual Studio / Build Tools, or run with -SkipBuild.' }

    Write-Host "Building ($Configuration) with $msbuild" -ForegroundColor Cyan
    & $msbuild (Join-Path $projectDir 'LegacyDatabaseMigrationPOC.csproj') /t:Build "/p:Configuration=$Configuration" /v:m /nologo
    if ($LASTEXITCODE -ne 0) { throw "Build failed (exit code $LASTEXITCODE)." }
}

function Invoke-Ef6([string[]]$arguments, [switch]$Capture) {
    if (-not (Test-Path $ef6)) { throw "ef6.exe not found at $ef6. Restore NuGet packages first." }
    if (-not (Test-Path $assembly)) { throw "Assembly not found at $assembly. Build first (or drop -SkipBuild)." }

    # ef6.exe resolves a relative --config against the assembly folder, so pass absolute paths.
    $common = @('--assembly', $assembly, '--config', $webConfig, '--project-dir', $projectDir, '--no-color')

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # stderr output from a native command must not become a terminating error
    try {
        if ($Capture) { return (& $ef6 @arguments @common 2>&1 | ForEach-Object { "$_" }) }
        & $ef6 @arguments @common
    }
    finally { $ErrorActionPreference = $previous }
}

# ---------------------------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------------------------

function Invoke-Migrate($conn) {
    Write-Host "== $($conn.Name): migrating database '$(Get-DatabaseName $conn.Parts)' ==" -ForegroundColor Cyan
    Invoke-Ef6 @(
        'database', 'update',
        '--migrations-config', $conn.Info.MigrationsConfig,
        '--connection-string', $conn.ConnectionString,
        '--connection-provider', $conn.Info.Invariant,
        '--verbose')
    if ($LASTEXITCODE -ne 0) { throw "$($conn.Name): ef6 database update failed (exit code $LASTEXITCODE)." }
}

function Invoke-GenerateScript($conn) {
    $target = Join-Path $scriptsDir "$($conn.Name)\Migrations.sql"
    Write-Host "== $($conn.Name): generating $target ==" -ForegroundColor Cyan

    $arguments = @(
        'database', 'update', '--script', '--prefix-output',
        '--migrations-config', $conn.Info.MigrationsConfig,
        '--connection-provider', $conn.Info.Invariant)

    if ($conn.Name -eq 'SqlServer') {
        # From the empty-database marker: EF guards every migration with a __MigrationHistory
        # check, so the resulting script is safe to re-run.
        $arguments += @('--source', '0', '--connection-string', $conn.ConnectionString)
    }
    else {
        # EF6.Npgsql 6.4 throws NullReferenceException when scripting from the empty-database
        # marker. Scripting the pending migrations against a database name that does not exist
        # gives the same output: every migration is pending and nothing is applied or created.
        $scratch = Set-DatabaseName $conn.ConnectionString ((Get-DatabaseName $conn.Parts) + '_ef6script')
        $arguments += @('--connection-string', $scratch)
    }

    $output = Invoke-Ef6 $arguments -Capture
    if ($LASTEXITCODE -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "$($conn.Name): script generation failed (exit code $LASTEXITCODE)."
    }

    # With --prefix-output every line is tagged; the script itself is on the "data:" lines.
    if ($conn.Name -eq 'SqlServer') {
        $sql = @($output | Where-Object { $_ -match '^data:' } | ForEach-Object { $_ -replace '^data:\s{0,4}', '' })
        $guardNote = '-- EF wraps every migration in a dbo.__MigrationHistory check, so the script is safe to re-run.'
    }
    else {
        $sql = @(ConvertTo-GuardedPostgreSqlScript $output)
        $guardNote = '-- Every migration is wrapped in a DO block that skips it when dbo.__MigrationHistory already lists it, so the script is safe to re-run.'
    }
    if ($sql.Count -eq 0) { throw "$($conn.Name): ef6 returned no script." }

    $header = @(
        "-- $($conn.Name) migration script for LegacyDatabaseMigrationPOC.",
        '-- Generated by Database\Setup-Database.ps1 -GenerateScripts (ef6.exe, EntityFramework 6.5.2). Do not edit by hand.',
        '-- Takes an EMPTY database to the latest EF6 migration and records it in dbo.__MigrationHistory,',
        '-- so the application and Update-Database treat the schema as fully migrated.',
        $guardNote,
        '-- The database itself must already exist: Setup-Database.ps1 -ApplyScripts creates it and then',
        '-- runs this file followed by SeedData.sql.',
        '')

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    [System.IO.File]::WriteAllLines($target, [string[]]($header + $sql))
    Write-Host "   wrote $($sql.Count) lines."
}

# The Npgsql generator emits plain statements with no re-run protection. ef6 --prefix-output tells us
# which migration each statement belongs to ("info: Applying explicit migration: <id>."), so each
# migration's statements are wrapped in a DO block that returns early when __MigrationHistory
# already contains the id. That mirrors the guards EF itself emits for SQL Server.
function ConvertTo-GuardedPostgreSqlScript([string[]]$output) {
    $migrations = @()
    $current = $null
    $buffer = @()

    foreach ($line in $output) {
        if ($line -match '^info:\s+Applying explicit migration: (\S+)\.\s*$') {
            if ($current -and $buffer.Count -gt 0) { $current.Statements += ($buffer -join "`n") }
            $current = @{ Id = $Matches[1]; Statements = @() }
            $migrations += $current
            $buffer = @()
            continue
        }
        if (-not $current -or $line -notmatch '^data:') { continue }

        $text = ($line -replace '^data:\s{0,4}', '').TrimEnd()
        if ($text -eq ';') {
            if ($buffer.Count -gt 0) { $current.Statements += ($buffer -join "`n"); $buffer = @() }
        }
        elseif ($text.Trim()) {
            $buffer += $text
        }
    }
    if ($current -and $buffer.Count -gt 0) { $current.Statements += ($buffer -join "`n") }

    $lines = @()
    foreach ($migration in $migrations) {
        $id = $migration.Id
        $lines += "-- Migration $id"
        $lines += 'DO $ef6migration$'
        $lines += 'BEGIN'
        $lines += "    IF to_regclass('dbo.""__MigrationHistory""') IS NOT NULL THEN"
        $lines += "        IF EXISTS (SELECT 1 FROM dbo.""__MigrationHistory"" WHERE ""MigrationId"" = '$id') THEN"
        $lines += "            RAISE NOTICE 'Migration $id is already applied, skipping.';"
        $lines += '            RETURN;'
        $lines += '        END IF;'
        $lines += '    END IF;'
        $lines += ''
        foreach ($statement in $migration.Statements) {
            $lines += @($statement -split "`n" | ForEach-Object { '    ' + $_ })
            $lines[-1] = $lines[-1] + ';'
        }
        $lines += 'END'
        $lines += '$ef6migration$;'
        $lines += ''
    }
    return $lines
}

function Invoke-ApplyScripts($conn) {
    $dir        = Join-Path $scriptsDir $conn.Name
    $migrations = Join-Path $dir 'Migrations.sql'
    $seed       = Join-Path $dir 'SeedData.sql'
    if (-not (Test-Path $migrations)) { throw "Missing $migrations. Run Setup-Database.ps1 -GenerateScripts first." }

    $files = @($migrations, $seed) | Where-Object { Test-Path $_ }
    $db    = Get-DatabaseName $conn.Parts
    Write-Host "== $($conn.Name): applying SQL scripts to database '$db' ==" -ForegroundColor Cyan

    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if ($conn.Name -eq 'SqlServer') {
            if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) { throw 'sqlcmd not found on PATH.' }

            $server   = Get-FirstValue $conn.Parts @('server', 'data source')
            $security = Get-FirstValue $conn.Parts @('integrated security', 'trusted_connection')
            if ($security -and $security -match '^(true|yes|sspi)$') {
                $auth = @('-E')
            }
            else {
                $auth = @('-U', (Get-FirstValue $conn.Parts @('user id', 'uid', 'user')), '-P', (Get-FirstValue $conn.Parts @('password', 'pwd')))
            }
            $base = @('-S', $server) + $auth + @('-b')   # -b: non-zero exit code on SQL errors

            & sqlcmd @base -Q "IF DB_ID(N'$db') IS NULL CREATE DATABASE [$db];"
            if ($LASTEXITCODE -ne 0) { throw "sqlcmd: creating database '$db' failed." }

            foreach ($file in $files) {
                Write-Host "   running $(Split-Path -Leaf $file)"
                & sqlcmd @base -d $db -i $file
                if ($LASTEXITCODE -ne 0) { throw "sqlcmd: $file failed." }
            }
        }
        else {
            if (-not (Get-Command psql -ErrorAction SilentlyContinue)) { throw 'psql not found on PATH (add C:\Program Files\PostgreSQL\<version>\bin).' }

            $pgHost = Get-FirstValue $conn.Parts @('host', 'server')
            $port   = Get-FirstValue $conn.Parts @('port')
            if (-not $port) { $port = '5432' }
            $user   = Get-FirstValue $conn.Parts @('username', 'user id', 'user')
            $pwd    = Get-FirstValue $conn.Parts @('password')
            $base   = @('-h', $pgHost, '-p', $port, '-U', $user, '-v', 'ON_ERROR_STOP=1', '-q')

            $previousPassword = $env:PGPASSWORD
            try {
                if ($pwd) { $env:PGPASSWORD = $pwd }

                $exists = & psql @base -d postgres -At -c "SELECT 1 FROM pg_database WHERE datname = '$db'"
                if ($LASTEXITCODE -ne 0) { throw 'psql: could not query pg_database.' }
                if ("$exists" -ne '1') {
                    & psql @base -d postgres -c "CREATE DATABASE `"$db`""
                    if ($LASTEXITCODE -ne 0) { throw "psql: creating database '$db' failed." }
                }

                foreach ($file in $files) {
                    Write-Host "   running $(Split-Path -Leaf $file)"
                    & psql @base -d $db -f $file
                    if ($LASTEXITCODE -ne 0) { throw "psql: $file failed." }
                }
            }
            finally { $env:PGPASSWORD = $previousPassword }
        }
    }
    finally { $ErrorActionPreference = $previous }
}

# ---------------------------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------------------------

if (-not $ApplyScripts) { Invoke-Build }

foreach ($name in $selected) {
    $conn = Resolve-Connection $name
    if ($ApplyScripts)        { Invoke-ApplyScripts $conn }
    elseif ($GenerateScripts) { Invoke-GenerateScript $conn }
    else                      { Invoke-Migrate $conn }
    Write-Host ''
}

Write-Host 'Done.' -ForegroundColor Green
