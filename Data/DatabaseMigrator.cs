using System;
using System.Collections.Generic;
using System.Data.Entity.Infrastructure;
using System.Data.Entity.Migrations;
using System.Data.Entity.Migrations.Infrastructure;
using System.Linq;
using Npgsql;

namespace LegacyDatabaseMigrationPOC.Data
{
    /// <summary>Migration state of one provider's database.</summary>
    public sealed class MigrationStatus
    {
        public DatabaseProvider Provider { get; set; }
        public string ConnectionStringName { get; set; }
        public bool DatabaseExists { get; set; }
        public IList<string> Local { get; set; }
        public IList<string> Applied { get; set; }
        public IList<string> Pending { get; set; }

        public bool IsUpToDate
        {
            get { return DatabaseExists && Pending.Count == 0; }
        }
    }

    /// <summary>
    /// Runs EF6 code-first migrations against either provider.
    /// Each provider has its own DbMigrationsConfiguration (Migrations\SqlServer and
    /// Migrations\PostgreSql) because every EF6 migration embeds a provider-specific model
    /// snapshot: a migration scaffolded for SQL Server cannot be applied to PostgreSQL.
    /// </summary>
    public static class DatabaseMigrator
    {
        public static readonly DatabaseProvider[] AllProviders =
        {
            DatabaseProvider.SqlServer,
            DatabaseProvider.PostgreSql
        };

        public static DbMigrationsConfiguration GetConfiguration(DatabaseProvider provider)
        {
            switch (provider)
            {
                case DatabaseProvider.SqlServer:
                    return new LegacyDatabaseMigrationPOC.Migrations.SqlServer.Configuration();
                case DatabaseProvider.PostgreSql:
                    return new LegacyDatabaseMigrationPOC.Migrations.PostgreSql.Configuration();
                default:
                    throw new ArgumentOutOfRangeException(nameof(provider), provider, "Unknown database provider.");
            }
        }

        public static DbMigrator CreateMigrator(DatabaseProvider provider)
        {
            return new DbMigrator(GetConfiguration(provider));
        }

        /// <summary>Creates the database when missing, applies pending migrations and runs the seed.</summary>
        public static void MigrateToLatest(DatabaseProvider provider)
        {
            CreateMigrator(provider).Update();
        }

        public static MigrationStatus GetStatus(DatabaseProvider provider)
        {
            var migrator = CreateMigrator(provider);

            bool databaseExists;
            using (var db = new AppDbContext(provider))
            {
                databaseExists = db.Database.Exists();
            }

            return new MigrationStatus
            {
                Provider = provider,
                ConnectionStringName = DatabaseProviderSettings.GetConnectionStringName(provider),
                DatabaseExists = databaseExists,
                Local = migrator.GetLocalMigrations().ToList(),
                Applied = migrator.GetDatabaseMigrations().ToList(),
                Pending = migrator.GetPendingMigrations().ToList()
            };
        }

        /// <summary>
        /// SQL that takes an empty database to the latest migration for the given provider,
        /// including the __MigrationHistory rows. Nothing is applied.
        /// </summary>
        public static string ScriptAllMigrations(DatabaseProvider provider)
        {
            if (provider == DatabaseProvider.SqlServer)
            {
                // Scripted from the empty-database marker: EF wraps each migration in a
                // __MigrationHistory check, so the script is safe to re-run.
                return new MigratorScriptingDecorator(CreateMigrator(provider))
                    .ScriptUpdate(DbMigrator.InitialDatabase, null);
            }

            // EF6.Npgsql 6.4 throws NullReferenceException when scripting from the empty-database
            // marker. Scripting the pending migrations against a database name that does not exist
            // gives the same output: every migration is pending and nothing is applied or created.
            var configuration = GetConfiguration(provider);
            configuration.TargetDatabase = new DbConnectionInfo(
                PostgreSqlScriptingConnectionString(),
                DatabaseProviderSettings.GetProviderInvariantName(DatabaseProvider.PostgreSql));
            return new MigratorScriptingDecorator(new DbMigrator(configuration)).ScriptUpdate(null, null);
        }

        private static string PostgreSqlScriptingConnectionString()
        {
            var connectionString = DatabaseProviderSettings.GetConnectionString(DatabaseProvider.PostgreSql);
            var builder = new NpgsqlConnectionStringBuilder(connectionString);
            builder.Database = builder.Database + "_ef6script";
            return builder.ConnectionString;
        }
    }
}
