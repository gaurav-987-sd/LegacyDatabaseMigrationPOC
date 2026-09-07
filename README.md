# LegacyDatabaseMigrationPOC: setup guide

ASP.NET MVC 5 (.NET Framework 4.8) proof of concept for moving a legacy application from
SQL Server to PostgreSQL. The same code runs against either database, and one setting in
`Web.config` chooses which. This guide takes you from a fresh clone to a working, seeded database
on **both** engines and shows how to confirm the application is really connected.

How the migrations are organised internally, and how to add a new one, is described in
[Database/README.md](Database/README.md).

## 1. What you need

| Component                                 | Notes                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------ |
| Windows 10 / 11                           | .NET Framework 4.8 is part of Windows.                                                     |
| Visual Studio 2022                        | Workload **ASP.NET and web development**. Community edition is fine.                       |
| SQL Server                                | Any edition: Developer, Express, or LocalDB (LocalDB ships with Visual Studio).            |
| PostgreSQL 13 or newer                    | Windows installer from postgresql.org. Remember the password you give the `postgres` user. |
| Optional: `sqlcmd` and `psql` on the PATH | Only needed for the plain-SQL setup (section 4, option D).                                 |

Both database servers must be running before you create the databases.

## 2. Install and build the project

1. Clone the repository and open `LegacyDatabaseMigrationPOC.sln` in Visual Studio.
2. Restore NuGet packages: right-click the solution and choose **Restore NuGet Packages**
   (Visual Studio also does this on the first build). The `packages` folder is not in git.
3. Build the solution with **Build > Build Solution**. It must build cleanly before any database step.

Command-line alternative, from a *Developer PowerShell for VS 2022* prompt:

```powershell
nuget restore LegacyDatabaseMigrationPOC.sln
msbuild LegacyDatabaseMigrationPOC.csproj /t:Build /p:Configuration=Debug
```

## 3. Configure the connections (Web.config)

Everything you may need to change is in two places in `Web.config`.

### 3.1 Connection strings

```xml
<connectionStrings>
  <add name="PostgresConnection"  providerName="Npgsql"
       connectionString="Host=localhost;Port=5432;Database=LegacyDatabaseMigrationPOC;Username=postgres;Password=root" />
  <add name="SqlServerConnection" providerName="System.Data.SqlClient"
       connectionString="Server=localhost,1433;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True" />
</connectionStrings>
```

Keep the two `name` values exactly as they are; the code looks them up by name. Change the
`connectionString` values to match your machine:

| Your setup                                              | connectionString                                                                                                           |
| ------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| SQL Server default instance, Windows login (as shipped) | `Server=localhost,1433;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True`         |
| SQL Server Express                                      | `Server=.\SQLEXPRESS;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True`           |
| LocalDB (installed with Visual Studio)                  | `Server=(localdb)\MSSQLLocalDB;Database=LegacyDatabaseMigrationPOC;Integrated Security=True;MultipleActiveResultSets=True` |
| SQL Server with a SQL login                             | `Server=localhost,1433;Database=LegacyDatabaseMigrationPOC;User ID=sa;Password=YourPassword;MultipleActiveResultSets=True` |
| PostgreSQL (as shipped)                                 | `Host=localhost;Port=5432;Database=LegacyDatabaseMigrationPOC;Username=postgres;Password=root`                             |
| PostgreSQL, other port or user                          | `Host=localhost;Port=5433;Database=LegacyDatabaseMigrationPOC;Username=appuser;Password=YourPassword`                      |

The database named in the connection string does **not** need to exist yet: the setup step creates
it. The login must be allowed to create databases. A SQL Server sysadmin (your Windows account on a
local install) and the PostgreSQL `postgres` user both are.

### 3.2 Application settings

```xml
<appSettings>
  <add key="DatabaseProvider"    value="PostgreSql" />
  <add key="AutoMigrateDatabase" value="true" />
</appSettings>
```

| Setting               | Values                      | Meaning                                                                                                                                                                                               |
| --------------------- | --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `DatabaseProvider`    | `SqlServer` or `PostgreSql` | Which connection string the application uses.                                                                                                                                                         |
| `AutoMigrateDatabase` | `true` or `false`           | `true`: the first time the application touches a database it creates it, applies the migrations and seeds it. `false`: the application never changes the schema; create the databases with section 4. |

## 4. Create and seed the databases

Pick one option. Each one creates the database if it is missing, creates the `dbo.Customers`
table, records the migration in `dbo.__MigrationHistory` and seeds 10 sample customers. All of them
can be run again safely; a database that is already up to date is left alone.

### Option A: from the browser (easiest)

1. Press **F5** in Visual Studio. The site opens on IIS Express at `https://localhost:44376/`.
2. Browse to `https://localhost:44376/DatabaseTest/Migrate?provider=All`.

That one page sets up **both** databases. Use `?provider=SqlServer` or `?provider=PostgreSql` to
set up only one. You should see:

```text
== SqlServer: applying migrations ==
Migration completed.

== SqlServer ==
Connection string: SqlServerConnection
Database exists:   True
Up to date:        True
...
== PostgreSql: applying migrations ==
Migration completed.
```

### Option B: PowerShell script

```powershell
cd <project folder>
.\Database\Setup-Database.ps1                       # both databases
.\Database\Setup-Database.ps1 -Provider PostgreSql  # one database
```

The script builds the project and runs the EF6 migrations with `ef6.exe`. If PowerShell refuses to
run scripts, use `powershell -ExecutionPolicy Bypass -File .\Database\Setup-Database.ps1`.

### Option C: Package Manager Console in Visual Studio

Open **Tools > NuGet Package Manager > Package Manager Console** and run one line per provider:

```powershell
Update-Database -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration
Update-Database -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration
```

### Option D: plain SQL scripts (no build, for example for a DBA)

`Database\Scripts\SqlServer\` and `Database\Scripts\PostgreSql\` each contain `Migrations.sql`
(schema plus migration history) and `SeedData.sql` (sample rows). Create the database, then run the
two files in that order in SQL Server Management Studio or pgAdmin. Or let the script do all three
steps (needs `sqlcmd` and `psql` on the PATH):

```powershell
.\Database\Setup-Database.ps1 -ApplyScripts
```

## 5. Check that the database is connected

Run the site (F5) and open these pages. They return plain text, so they are easy to read and to
paste into a bug report.

### 5.1 `/DatabaseTest/Current`: is the active provider connected?

```text
Configured Provider: PostgreSql (appSettings/DatabaseProvider)
Connection String: PostgresConnection
Database: LegacyDatabaseMigrationPOC
Connection Type: Npgsql.NpgsqlConnection
Server Version: 18.3
```

`Connection Type` shows which driver is really in use: `Npgsql.NpgsqlConnection` for PostgreSQL,
`System.Data.SqlClient.SqlConnection` for SQL Server. If the connection fails, the page shows the
full error instead. This page only opens a connection, so run section 4 first.

### 5.2 `/DatabaseTest/Status`: are both databases created and migrated?

```text
Configured provider: PostgreSql (appSettings/DatabaseProvider)
Auto-migrate on first use: True (appSettings/AutoMigrateDatabase)

== SqlServer ==
Connection string: SqlServerConnection
Database exists:   True
Up to date:        True
Local migrations:  202608190627453_InitialCreate
Applied:           202608190627453_InitialCreate
Pending:           (none)

== PostgreSql ==
Connection string: PostgresConnection
Database exists:   True
Up to date:        True
Local migrations:  202609071103352_InitialCreate
Applied:           202609071103352_InitialCreate
Pending:           (none)
```

`Database exists: False`, or anything under `Pending`, means section 4 has not been done for that
provider yet.

### 5.3 `/DatabaseTest/Customers?provider=SqlServer` and `?provider=PostgreSql`: is the data there?

```text
PostgreSql: 10 customer(s)
1    John Smith       john.smith@example.com       2026-01-10 09:30    active
2    Sarah Johnson    sarah.johnson@example.com    2026-01-11 10:15    active
...
10   Olivia White     olivia.white@example.com     2026-01-19 13:40    active
```

Both providers list the same 10 rows. Without `?provider=` the page uses the active provider.

### 5.4 Other pages

| Page                                       | Purpose                                                         |
| ------------------------------------------ | --------------------------------------------------------------- |
| `/DatabaseTest/SqlServer`                  | Quick connectivity check for SQL Server only.                   |
| `/DatabaseTest/PostgreSql`                 | Quick connectivity check for PostgreSQL only.                   |
| `/DatabaseTest/Script?provider=PostgreSql` | Shows the SQL the migration runs (also works with `SqlServer`). |

### 5.5 Check directly in the database tools

SQL Server Management Studio:

```sql
USE LegacyDatabaseMigrationPOC;
SELECT MigrationId, ContextKey FROM dbo.__MigrationHistory;
SELECT * FROM dbo.Customers;
```

pgAdmin, or `psql -U postgres -d LegacyDatabaseMigrationPOC` (the quotes are required):

```sql
select "MigrationId", "ContextKey" from dbo."__MigrationHistory";
select * from dbo."Customers";
```

Expected: one migration row and 10 customers in each database.

## 6. Switch between SQL Server and PostgreSQL

1. In `Web.config`, set `DatabaseProvider` to `SqlServer` or `PostgreSql`.
2. Save the file. IIS Express restarts the application; if a page still shows the old provider,
   stop debugging and press F5 again.
3. Open `/DatabaseTest/Current` and check `Connection Type`.

Nothing else changes. Both databases stay in place, so you can switch back and forth at any time.

## 7. Troubleshooting

| Symptom                                                                                               | Cause and fix                                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Build error *This project references NuGet package(s) that are missing*                               | Restore NuGet packages (section 2).                                                                                                                                                                                                                                                      |
| *A network-related or instance-specific error occurred while establishing a connection to SQL Server* | SQL Server is not running, or `localhost,1433` is not reachable. Start the **SQL Server (MSSQLSERVER)** service. For Express or LocalDB use the matching connection string from section 3.1. When connecting by `host,port`, TCP/IP must be enabled in SQL Server Configuration Manager. |
| *Login failed for user* (SQL Server)                                                                  | The login has no access. Use a sysadmin login, or grant the login access to the database.                                                                                                                                                                                                |
| PostgreSQL: *No connection could be made* or *connection refused*                                     | The PostgreSQL service is not running or listens on another port. Check **Services** for `postgresql-x64-<version>` and the `Port` value in the connection string.                                                                                                                       |
| PostgreSQL: *password authentication failed for user "postgres"*                                      | Wrong `Password` in `PostgresConnection`.                                                                                                                                                                                                                                                |
| PostgreSQL: *database "LegacyDatabaseMigrationPOC" does not exist* on `/DatabaseTest/Current`         | That page only opens a connection and does not create the database. Run section 4 first.                                                                                                                                                                                                 |
| *Unable to update database to match the current model because there are pending changes*              | The model changed but a migration is missing for that provider. See "Adding a migration" in `Database/README.md`.                                                                                                                                                                        |
| `Setup-Database.ps1`: *ef6.exe not found*                                                             | NuGet packages are not restored (section 2).                                                                                                                                                                                                                                             |
| `Setup-Database.ps1`: *running scripts is disabled on this system*                                    | Run it as `powershell -ExecutionPolicy Bypass -File .\Database\Setup-Database.ps1`.                                                                                                                                                                                                      |
| `/DatabaseTest/...` returns 404                                                                       | The site is not running, or the URL is missing the port. Start with F5 and use the address Visual Studio opens.                                                                                                                                                                          |

## 8. Where things are

| Path                                              | What it is                                                            |
| ------------------------------------------------- | --------------------------------------------------------------------- |
| `Web.config`                                      | Connection strings, `DatabaseProvider`, `AutoMigrateDatabase`.        |
| `Data\AppDbContext.cs`                            | The EF6 context. Picks the connection string from `DatabaseProvider`. |
| `Data\DatabaseMigrator.cs`                        | Runs, reports and scripts migrations for either provider.             |
| `Migrations\SqlServer\`, `Migrations\PostgreSql\` | One EF6 migration set per provider (they cannot be shared).           |
| `Migrations\SeedData.cs`                          | The 10 sample customers, applied after every migration run.           |
| `Controllers\DatabaseTestController.cs`           | The `/DatabaseTest/...` diagnostic pages.                             |
| `Database\Setup-Database.ps1`                     | Command-line setup, SQL script generation, plain-SQL setup.           |
| `Database\Scripts\`                               | Generated SQL for both engines plus seed scripts.                     |
| `Database\README.md`                              | How the dual migrations work and how to add a new migration.          |
