<#
.SYNOPSIS
    Example local environment settings for LegacyDatabaseMigrationPOC.

.DESCRIPTION
    The application reads DatabaseProvider, AutoMigrateDatabase, SqlServerConnection and
    PostgresConnection from environment variables, falling back to Web.config when a variable is
    not set (see section 3.3 of the root README). This file is a starting point for setting them
    locally so your own credentials never go into Web.config.

    To use it:
        1. Copy this file to Database\set-local-env.ps1  (that name is gitignored)
        2. Put your real values in the copy
        3. Dot-source it - note the leading dot and space, which is what makes the variables
           apply to your current shell rather than to a child process that then exits:

               . .\Database\set-local-env.ps1

    Anything you start from that shell inherits the values, including Setup-Database.ps1 and
    IIS Express. They disappear when you close the shell.

    Visual Studio is the exception. Pressing F5 launches IIS Express from devenv.exe, which
    inherited its environment when Visual Studio started, so a shell variable will not reach it.
    Use -Persist to write the values to your Windows user account instead, then restart
    Visual Studio:

               . .\Database\set-local-env.ps1 -Persist

    To remove everything again:

               . .\Database\set-local-env.ps1 -Clear          # this shell
               . .\Database\set-local-env.ps1 -Clear -Persist # and the user account

.PARAMETER Persist
    Also write the values to the Windows user account, so Visual Studio picks them up after a
    restart. Without this switch the values apply to the current shell only.

.PARAMETER Clear
    Remove the variables instead of setting them.
#>
[CmdletBinding()]
param(
    [switch]$Persist,
    [switch]$Clear
)

# ---------------------------------------------------------------------------------------------
# Your values. Set only what you want to override; anything left empty falls back to Web.config.
# ---------------------------------------------------------------------------------------------

$settings = [ordered]@{
    # SqlServer or PostgreSql.
    DatabaseProvider = 'PostgreSql'

    # true: create and migrate the database on first use. false: leave the schema alone.
    AutoMigrateDatabase = 'true'

    # Whole connection strings. There is no merging with Web.config: set all of it or none of it.
    SqlServerConnection = 'Server=localhost,1433;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True'
    PostgresConnection = 'Host=localhost;Port=5432;Database=LegacyDatabaseMigrationPOC;Username=postgres;Password=CHANGE_ME'
}

# ---------------------------------------------------------------------------------------------

# Hides the password so the summary below is safe to paste into a chat or a ticket.
function Format-Masked([string]$name, [string]$value) {
    if (-not $value) { return '(not set)' }
    if ($name -notlike '*Connection*') { return $value }
    return [regex]::Replace($value, '(?i)(password\s*=\s*)([^;]*)', '${1}***')
}

foreach ($name in $settings.Keys) {
    $value = $settings[$name]

    if ($Clear) {
        Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue
        if ($Persist) { [Environment]::SetEnvironmentVariable($name, $null, 'User') }
        continue
    }

    if ([string]::IsNullOrWhiteSpace($value)) { continue }

    Set-Item -LiteralPath "env:$name" -Value $value
    if ($Persist) { [Environment]::SetEnvironmentVariable($name, $value, 'User') }
}

if ($Clear) {
    $scope = if ($Persist) { 'this shell and the user account' } else { 'this shell' }
    Write-Host "Cleared LegacyDatabaseMigrationPOC environment variables from $scope." -ForegroundColor Green
    if ($Persist) { Write-Host 'Restart Visual Studio for it to notice.' -ForegroundColor Yellow }
    return
}

Write-Host 'LegacyDatabaseMigrationPOC environment variables set for this shell:' -ForegroundColor Green
foreach ($name in $settings.Keys) {
    Write-Host ("  {0,-20} {1}" -f $name, (Format-Masked $name $settings[$name]))
}

if ($Persist) {
    Write-Host ''
    Write-Host 'Also written to your Windows user account. Restart Visual Studio to pick them up.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Check what the application actually resolved with /DatabaseTest/Current or /DatabaseTest/Status.'
