using System.Data.Entity;
using LegacyDatabaseMigrationPOC.Data;

namespace LegacyDatabaseMigrationPOC
{
    public static class DatabaseConfig
    {
        /// <summary>
        /// Replaces EF's default CreateDatabaseIfNotExists initializer, which would create an
        /// unmigrated database on first use. With "AutoMigrateDatabase" enabled the database
        /// for the active provider is created and migrated on first use instead; otherwise
        /// nothing touches the schema and migrations must be run explicitly
        /// (Database\Setup-Database.ps1 or /DatabaseTest/Migrate).
        /// </summary>
        public static void RegisterDatabaseInitializer()
        {
            if (DatabaseProviderSettings.AutoMigrateEnabled)
            {
                Database.SetInitializer(new MigrateToLatestVersionInitializer());
            }
            else
            {
                Database.SetInitializer<AppDbContext>(null);
            }
        }
    }
}
