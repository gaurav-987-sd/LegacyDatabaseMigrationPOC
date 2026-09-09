using System.Data.Common;
using System.Data.Entity;
using System.Data.SqlClient;
using LegacyDatabaseMigrationPOC.Models;
using Npgsql;

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

        /// <summary>
        /// Connects by connection string NAME, which lets Entity Framework read the provider from
        /// the Web.config entry.
        ///
        /// This constructor exists for the EF migrations pipeline, which instantiates the context
        /// itself and then replaces the connection using the TargetDatabase of the migrations
        /// configuration; that replacement is only possible on a context created this way. The
        /// environment-variable override still reaches migrations, because TargetDatabase carries
        /// the fully resolved connection string (see Migrations\*\Configuration.cs).
        ///
        /// Application code should use the AppDbContext(DatabaseProvider) constructor instead, so
        /// that the override applies and the provider is never inferred.
        /// </summary>
        public AppDbContext()
            : base(DatabaseProviderSettings.GetCurrentConnectionStringName())
        {
        }

        public AppDbContext(DatabaseProvider provider)
            : base(CreateConnection(provider), contextOwnsConnection: true)
        {
        }

<<<<<<< HEAD
=======
        private static string ResolveConnectionString()
        {
            var provider = ConfigurationManager.AppSettings["DatabaseProvider"];
            var envVarName = string.Equals(provider, "PostgreSql", StringComparison.OrdinalIgnoreCase)
                ? "PostgresConnection"
                : "AppDbConnection";
            
            var fromEnv = Environment.GetEnvironmentVariable(envVarName);
            if (!string.IsNullOrEmpty(fromEnv))
                return fromEnv;
            
            return envVarName;
        }

>>>>>>> 995f143 (Read DB connection string from env var)
        public DbSet<Customer> Customers { get; set; }

        /// <summary>
        /// Builds the connection for a provider from its resolved connection string.
        ///
        /// The connection type is chosen here rather than left to Entity Framework on purpose.
        /// Handing DbContext a raw connection string makes it build the connection with the
        /// defaultConnectionFactory from Web.config, which is the Npgsql one, so a SQL Server
        /// connection string supplied through the environment would be given to Npgsql and fail.
        /// Creating the connection explicitly keeps both providers working.
        /// </summary>
        private static DbConnection CreateConnection(DatabaseProvider provider)
        {
            var connectionString = DatabaseProviderSettings.GetConnectionString(provider);

            return provider == DatabaseProvider.PostgreSql
                ? (DbConnection)new NpgsqlConnection(connectionString)
                : new SqlConnection(connectionString);
        }
    }
}
