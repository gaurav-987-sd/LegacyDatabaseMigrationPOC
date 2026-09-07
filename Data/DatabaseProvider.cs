using System;
using System.Configuration;

namespace LegacyDatabaseMigrationPOC.Data
{
    /// <summary>Database engines this application can run against.</summary>
    public enum DatabaseProvider
    {
        SqlServer,
        PostgreSql
    }

    /// <summary>
    /// Resolves the active database engine from Web.config (appSettings "DatabaseProvider")
    /// and maps each provider to its named connection string.
    /// </summary>
    public static class DatabaseProviderSettings
    {
        public const string AppSettingKey = "DatabaseProvider";
        public const string AutoMigrateAppSettingKey = "AutoMigrateDatabase";

        public const string SqlServerConnectionName = "SqlServerConnection";
        public const string PostgreSqlConnectionName = "PostgresConnection";

        /// <summary>Provider selected in Web.config. Anything other than PostgreSql falls back to SqlServer.</summary>
        public static DatabaseProvider Current
        {
            get
            {
                DatabaseProvider provider;
                return TryParse(ConfigurationManager.AppSettings[AppSettingKey], out provider)
                    ? provider
                    : DatabaseProvider.SqlServer;
            }
        }

        /// <summary>When true, pending migrations for a database are applied the first time its context is used.</summary>
        public static bool AutoMigrateEnabled
        {
            get
            {
                bool enabled;
                return bool.TryParse(ConfigurationManager.AppSettings[AutoMigrateAppSettingKey], out enabled) && enabled;
            }
        }

        public static bool TryParse(string value, out DatabaseProvider provider)
        {
            provider = DatabaseProvider.SqlServer;
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            var name = value.Trim();

            if (Matches(name, "SqlServer") || Matches(name, "MsSql") || Matches(name, "System.Data.SqlClient"))
            {
                provider = DatabaseProvider.SqlServer;
                return true;
            }

            if (Matches(name, "PostgreSql") || Matches(name, "Postgres") || Matches(name, "Npgsql"))
            {
                provider = DatabaseProvider.PostgreSql;
                return true;
            }

            return false;
        }

        public static string GetConnectionStringName(DatabaseProvider provider)
        {
            return provider == DatabaseProvider.PostgreSql
                ? PostgreSqlConnectionName
                : SqlServerConnectionName;
        }

        public static string GetCurrentConnectionStringName()
        {
            return GetConnectionStringName(Current);
        }

        private static bool Matches(string value, string candidate)
        {
            return string.Equals(value, candidate, StringComparison.OrdinalIgnoreCase);
        }
    }
}
