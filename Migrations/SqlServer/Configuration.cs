using System.Data.Entity.Infrastructure;
using System.Data.Entity.Migrations;
using LegacyDatabaseMigrationPOC.Data;

namespace LegacyDatabaseMigrationPOC.Migrations.SqlServer
{
    /// <summary>
    /// EF6 migrations for SQL Server. Migrations scaffolded with this configuration are written to
    /// Migrations\SqlServer and carry a SQL Server model snapshot, so they apply to SQL Server only.
    /// Every model change needs a migration here AND in Migrations\PostgreSql.
    ///
    /// Package Manager Console:
    ///   Add-Migration  Name -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration
    ///   Update-Database     -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration
    /// Command line: Database\Setup-Database.ps1 (see Database\README.md).
    /// </summary>
    internal sealed class Configuration : DbMigrationsConfiguration<AppDbContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = false;
            MigrationsDirectory = @"Migrations\SqlServer";
            ContextKey = AppDbContext.MigrationsContextKey;
            TargetDatabase = new DbConnectionInfo(DatabaseProviderSettings.SqlServerConnectionName);
        }

        protected override void Seed(AppDbContext context)
        {
            SeedData.Apply(context);
        }
    }
}
