using System.Data.Entity;
using Npgsql;

namespace LegacyDatabaseMigrationPOC.Data
{
    /// <summary>
    /// Provider-aware equivalent of EF's MigrateDatabaseToLatestVersion initializer.
    /// The first time an AppDbContext is used for a given connection, the migrations that
    /// belong to that connection's provider are applied (creating the database when missing)
    /// and the seed runs. Registered by DatabaseConfig when appSettings "AutoMigrateDatabase" is true.
    /// </summary>
    public sealed class MigrateToLatestVersionInitializer : IDatabaseInitializer<AppDbContext>
    {
        public void InitializeDatabase(AppDbContext context)
        {
            var provider = context.Database.Connection is NpgsqlConnection
                ? DatabaseProvider.PostgreSql
                : DatabaseProvider.SqlServer;

            DatabaseMigrator.MigrateToLatest(provider);
        }
    }
}
