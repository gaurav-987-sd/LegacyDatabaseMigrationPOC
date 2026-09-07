using System.Data.Entity.Infrastructure;
using System.Data.Entity.Migrations;
using LegacyDatabaseMigrationPOC.Data;

namespace LegacyDatabaseMigrationPOC.Migrations.PostgreSql
{
    /// <summary>
    /// EF6 migrations for PostgreSQL (Npgsql). Migrations scaffolded with this configuration are
    /// written to Migrations\PostgreSql and carry a PostgreSQL model snapshot, so they apply to
    /// PostgreSQL only. Every model change needs a migration here AND in Migrations\SqlServer.
    ///
    /// Package Manager Console:
    ///   Add-Migration  Name -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration
    ///   Update-Database     -ConfigurationTypeName LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration
    /// Command line: Database\Setup-Database.ps1 (see Database\README.md).
    /// </summary>
    internal sealed class Configuration : DbMigrationsConfiguration<AppDbContext>
    {
        public Configuration()
        {
            AutomaticMigrationsEnabled = false;
            MigrationsDirectory = @"Migrations\PostgreSql";
            ContextKey = AppDbContext.MigrationsContextKey;
            TargetDatabase = new DbConnectionInfo(DatabaseProviderSettings.PostgreSqlConnectionName);
        }

        protected override void Seed(AppDbContext context)
        {
            SeedData.Apply(context);
        }
    }
}
