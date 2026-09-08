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
    /// Single place where the active database engine and its connection string are resolved.
    ///
    /// Every setting can come from an environment variable or from Web.config, and the environment
    /// wins. The variable names are the same as the Web.config keys: "DatabaseProvider",
    /// "AutoMigrateDatabase", "SqlServerConnection" and "PostgresConnection". That keeps credentials
    /// out of Web.config on deployed machines without changing anything for a normal local setup,
    /// where no variables are set and Web.config is used exactly as before.
    ///
    /// The context, the migrator, both migration configurations and Database\Setup-Database.ps1 all
    /// resolve through here, so the application and the migration tooling can never end up pointing
    /// at different databases.
    /// </summary>
    public static class DatabaseProviderSettings
    {
        public const string AppSettingKey = "DatabaseProvider";
        public const string AutoMigrateAppSettingKey = "AutoMigrateDatabase";

        public const string SqlServerConnectionName = "SqlServerConnection";
        public const string PostgreSqlConnectionName = "PostgresConnection";

        public const string SqlServerInvariantName = "System.Data.SqlClient";
        public const string PostgreSqlInvariantName = "Npgsql";

        /// <summary>Provider selected by the environment or Web.config. Anything other than PostgreSql falls back to SqlServer.</summary>
        public static DatabaseProvider Current
        {
            get
            {
                DatabaseProvider provider;
                return TryParse(GetSetting(AppSettingKey), out provider)
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
                return bool.TryParse(GetSetting(AutoMigrateAppSettingKey), out enabled) && enabled;
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

            if (Matches(name, "SqlServer") || Matches(name, "MsSql") || Matches(name, SqlServerInvariantName))
            {
                provider = DatabaseProvider.SqlServer;
                return true;
            }

            if (Matches(name, "PostgreSql") || Matches(name, "Postgres") || Matches(name, PostgreSqlInvariantName))
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

        /// <summary>ADO.NET provider invariant name, needed wherever a raw connection string is used.</summary>
        public static string GetProviderInvariantName(DatabaseProvider provider)
        {
            return provider == DatabaseProvider.PostgreSql
                ? PostgreSqlInvariantName
                : SqlServerInvariantName;
        }

        /// <summary>
        /// The connection string for a provider: the environment variable when set, otherwise the
        /// Web.config entry of the same name.
        /// </summary>
        public static string GetConnectionString(DatabaseProvider provider)
        {
            var name = GetConnectionStringName(provider);

            var fromEnvironment = GetEnvironmentValue(name);
            if (fromEnvironment != null)
            {
                return fromEnvironment;
            }

            var settings = ConfigurationManager.ConnectionStrings[name];
            if (settings == null || string.IsNullOrWhiteSpace(settings.ConnectionString))
            {
                throw new ConfigurationErrorsException(
                    $"No connection string for {provider}. Set the environment variable '{name}', " +
                    $"or add a '{name}' entry to the connectionStrings section of Web.config.");
            }

            return settings.ConnectionString;
        }

        /// <summary>
        /// True when this provider's connection string comes from the environment rather than
        /// Web.config. For diagnostics only: never display the connection string itself, it
        /// normally contains a password.
        /// </summary>
        public static bool IsOverriddenByEnvironment(DatabaseProvider provider)
        {
            return GetEnvironmentValue(GetConnectionStringName(provider)) != null;
        }

        /// <summary>Environment variable first, Web.config appSettings second.</summary>
        private static string GetSetting(string key)
        {
            return GetEnvironmentValue(key) ?? ConfigurationManager.AppSettings[key];
        }

        /// <summary>Reads an environment variable, treating blank as not set.</summary>
        private static string GetEnvironmentValue(string key)
        {
            var value = Environment.GetEnvironmentVariable(key);
            return string.IsNullOrWhiteSpace(value) ? null : value;
        }

        private static bool Matches(string value, string candidate)
        {
            return string.Equals(value, candidate, StringComparison.OrdinalIgnoreCase);
        }
    }
}
