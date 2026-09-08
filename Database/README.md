# Database setup: SQL Server and PostgreSQL

The application runs against either SQL Server or PostgreSQL. Both databases can be created and
migrated from this repository, and the active one is switched in `Web.config`.

## Switching the provider

`Web.config`:

```xml
<connectionStrings>
  <add name="PostgresConnection"  providerName="Npgsql"                connectionString="Host=localhost;Port=5432;Database=LegacyDatabaseMigrationPOC;Username=postgres;Password=root" />
  <add name="SqlServerConnection" providerName="System.Data.SqlClient" connectionString="Server=localhost,1433;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True" />
</connectionStrings>
<appSettings>
  <add key="DatabaseProvider"    value="PostgreSql" />   <!-- SqlServer | PostgreSql -->
  <add key="AutoMigrateDatabase" value="true" />         <!-- create + migrate the active database on first use -->
</appSettings>
```

* `DatabaseProvider` selects the connection string that `AppDbContext` uses
  (`Data\DatabaseProvider.cs`). Any value other than `PostgreSql` means SQL Server.
* Both EF providers are registered in the `entityFramework/providers` section, so no code
  changes are needed to switch.
* Each setting can also come from an environment variable of the same name, which wins over
  `Web.config`. Resolution happens in one place, `DatabaseProviderSettings`
  (`Data\DatabaseProvider.cs`), and the context, the migrator, both migration configurations and
  `Setup-Database.ps1` all go through it, so the application and the migration tooling always agree
  on the target database. See section 3.3 of the [root README](../README.md).
* `AutoMigrateDatabase=true` registers `MigrateToLatestVersionInitializer`
  (`App_Start\DatabaseConfig.cs`): the first time a context is used, the migrations of that
  connection's provider are applied and the seed runs. Set it to `false` to leave the schema alone
  and run migrations explicitly.

## Why there are two migration folders

EF6 stores a snapshot of the model inside every migration (`*.resx`, `Target`). That snapshot is
provider-specific: it contains the provider name, the server manifest token and store column types
(`nvarchar`/`datetime`/`bit` for SQL Server, `varchar`/`timestamp`/`bool` for PostgreSQL).
Applying the SQL Server migration to PostgreSQL fails with
`AutomaticMigrationsDisabledException: ... there are pending changes` because the PostgreSQL model
never matches the SQL Server snapshot.

So each provider has its own `DbMigrationsConfiguration` and migration set:

| Provider   | Configuration type                                               | Folder                  |
| ---------- | ---------------------------------------------------------------- | ----------------------- |
| SQL Server | `LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration`  | `Migrations\SqlServer`  |
| PostgreSQL | `LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration` | `Migrations\PostgreSql` |

Both configurations share the same `ContextKey` (`AppDbContext.MigrationsContextKey`) and the same
seed (`Migrations\SeedData.cs`). Tables live in the `dbo` schema on both engines, which is what
EF6.Npgsql creates by default and keeps the two schemas alike.

## Setting up the databases

Any one of these gets you a migrated, seeded database. All are safe to re-run.

1. **Run the app.** With `AutoMigrateDatabase=true` the active provider's database is created and
   migrated on first use. Open `/DatabaseTest/Migrate` to do the same for *both* providers.
2. **PowerShell script** (builds, then runs `ef6.exe` for each provider):

   ```powershell
   .\Database\Setup-Database.ps1                      # both providers
   .\Database\Setup-Database.ps1 -Provider SqlServer  # one provider
   ```

3. **Package Manager Console** in Visual Studio (one call per provider):

   ```powershell
   Update-Database -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration
   Update-Database -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration
   ```

4. **Plain SQL, no build required.** `Database\Scripts\<Provider>\Migrations.sql` creates the schema
   and the `__MigrationHistory` rows; `SeedData.sql` inserts the sample rows. Either run them with
   your own tooling (create the database first) or let the script do it with `sqlcmd` / `psql`:

   ```powershell
   .\Database\Setup-Database.ps1 -ApplyScripts
   .\Database\Setup-Database.ps1 -ApplyScripts -Provider PostgreSql -DatabaseName SomeOtherName
   ```

## Adding a migration

Every model change needs a migration **for each provider**. Scaffold both, then refresh the SQL
scripts and commit all of it.

Package Manager Console:

```powershell
Add-Migration AddPhoneNumber -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration
Add-Migration AddPhoneNumber -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration
.\Database\Setup-Database.ps1 -GenerateScripts
```

Command line equivalent with `ef6.exe` (run from the project folder after a build; `--config`
must be an absolute path, and the generated files must be added to the `.csproj` by hand):

```powershell
$ef6 = 'packages\EntityFramework.6.5.2\tools\net45\any\ef6.exe'
& $ef6 migrations add AddPhoneNumber --migrations-config LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration `
    --assembly (Resolve-Path bin\LegacyDatabaseMigrationPOC.dll) --config (Resolve-Path Web.config) --project-dir (Get-Location)
```

Each `Add-Migration` connects to that provider's database to read `__MigrationHistory`, so both
servers must be reachable when scaffolding.

## Diagnostics endpoints

`Controllers\DatabaseTestController.cs` returns plain text:

| URL                                                   | What it shows                                                      |
| ----------------------------------------------------- | ------------------------------------------------------------------ |
| `/DatabaseTest/Current`                               | provider selected in `Web.config`, connection type, server version |
| `/DatabaseTest/SqlServer`, `/DatabaseTest/PostgreSql` | connectivity check for one provider                                |
| `/DatabaseTest/Status`                                | database exists / applied / pending migrations for both providers  |
| `/DatabaseTest/Migrate?provider=All`                  | create, migrate and seed (`All`, `SqlServer` or `PostgreSql`)      |
| `/DatabaseTest/Script?provider=PostgreSql`            | the full migration SQL for one provider                            |
| `/DatabaseTest/Customers?provider=SqlServer`          | rows from one provider (defaults to the selected one)              |

## Notes and caveats

* **Seed data.** `Migrations\SeedData.cs` runs after every migrate (EF behaviour) and matches rows
  on `Email`, so it re-inserts a deleted sample row. `Scripts\<Provider>\SeedData.sql` is the SQL
  equivalent for setups that do not use EF migrations.
* **PostgreSQL script generation.** EF6.Npgsql 6.4 throws `NullReferenceException` when scripting
  from the empty-database marker (`-SourceMigration $InitialDatabase`). `DatabaseMigrator` and
  `Setup-Database.ps1` work around it by scripting the pending migrations against a database name
  that does not exist (`<name>_ef6script`), which yields the same script without touching anything.
  Because Npgsql emits plain statements, `Setup-Database.ps1` then wraps each PostgreSQL migration
  in a `DO` block that skips it when `__MigrationHistory` already lists it, mirroring the checks
  EF emits for SQL Server. Both scripts are therefore safe to re-run.
* **Manifest token.** The PostgreSQL snapshot records the server version it was scaffolded
  against (18.3). EF compares store types, not the token, so it applies to other supported
  PostgreSQL versions as well.
* **Why the context has two constructors.** `AppDbContext(DatabaseProvider)` builds an explicit
  `SqlConnection` or `NpgsqlConnection`; application code uses it. The parameterless constructor
  connects by connection string *name* and exists for the EF migrations pipeline, which instantiates
  the context itself and then swaps in the connection from `TargetDatabase` — something EF can only
  do for a context created that way. Both migration configurations set `TargetDatabase` from the
  resolved connection string plus an explicit provider invariant name, so an environment override
  still reaches migrations. Handing a raw connection string to `DbContext(string)` is deliberately
  avoided: EF would then build the connection with the `defaultConnectionFactory` from `Web.config`,
  which is the Npgsql one, and a SQL Server connection string would be given to Npgsql and fail.
* **Existing SQL Server databases** migrated before the split keep working: the configuration was
  moved but its `ContextKey` (`LegacyDatabaseMigrationPOC.Migrations.Configuration`) and the
  migration id (`202608190627453_InitialCreate`) are unchanged.
