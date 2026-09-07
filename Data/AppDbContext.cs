using System.Data.Entity;
using LegacyDatabaseMigrationPOC.Models;

namespace LegacyDatabaseMigrationPOC.Data
{
    public class AppDbContext : DbContext
    {
        /// <summary>
        /// Value stored in __MigrationHistory.ContextKey. Both provider-specific migration
        /// configurations use this key, so databases migrated before the configurations were
        /// split into Migrations\SqlServer and Migrations\PostgreSql keep working.
        /// </summary>
        public const string MigrationsContextKey = "LegacyDatabaseMigrationPOC.Migrations.Configuration";

        /// <summary>Uses the provider selected by appSettings "DatabaseProvider".</summary>
        public AppDbContext()
            : base(DatabaseProviderSettings.GetCurrentConnectionStringName())
        {
        }

        public AppDbContext(string connectionStringName)
            : base(connectionStringName)
        {
        }

        public AppDbContext(DatabaseProvider provider)
            : this(DatabaseProviderSettings.GetConnectionStringName(provider))
        {
        }

        public DbSet<Customer> Customers { get; set; }
    }
}
