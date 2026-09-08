using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Web.Mvc;
using LegacyDatabaseMigrationPOC.Data;

namespace LegacyDatabaseMigrationPOC.Controllers
{
    /// <summary>
    /// Plain-text diagnostics for the dual-provider setup.
    ///   /DatabaseTest/Current                 provider selected in Web.config and whether it connects
    ///   /DatabaseTest/SqlServer               connectivity check for SQL Server
    ///   /DatabaseTest/PostgreSql              connectivity check for PostgreSQL
    ///   /DatabaseTest/Status                  applied and pending migrations for both providers
    ///   /DatabaseTest/Migrate?provider=All    create, migrate and seed (All | SqlServer | PostgreSql)
    ///   /DatabaseTest/Script?provider=X       full SQL migration script for one provider
    ///   /DatabaseTest/Customers?provider=X    rows from one provider (defaults to the selected one)
    /// </summary>
    public class DatabaseTestController : Controller
    {
        private static readonly string NL = Environment.NewLine;

        public ActionResult Current()
        {
            var provider = DatabaseProviderSettings.Current;

            try
            {
                using (var db = new AppDbContext(provider))
                {
                    db.Database.Connection.Open();

                    var connectionType = db.Database.Connection.GetType().FullName;
                    var databaseName = db.Database.Connection.Database;
                    var serverVersion = db.Database.Connection.ServerVersion;

                    return Text(
                        $"Configured Provider: {provider} ({DatabaseProviderSettings.AppSettingKey}){NL}" +
                        $"Connection String: {DatabaseProviderSettings.GetConnectionStringName(provider)} (from {SourceOf(provider)}){NL}" +
                        $"Database: {databaseName}{NL}" +
                        $"Connection Type: {connectionType}{NL}" +
                        $"Server Version: {serverVersion}");
                }
            }
            catch (Exception ex)
            {
                return Text("Connection FAILED:" + NL + ex);
            }
        }

        public ActionResult SqlServer()
        {
            try
            {
                using (var db = new AppDbContext(DatabaseProvider.SqlServer))
                {
                    var canConnect = db.Database.Exists();

                    return Text(
                        canConnect
                            ? "SqlServer connection successful."
                            : "SqlServer database does not exist.");
                }
            }
            catch (Exception ex)
            {
                return Text("SqlServer connection failed: " + ex.Message);
            }
        }

        public ActionResult PostgreSql()
        {
            try
            {
                using (var db = new AppDbContext(DatabaseProvider.PostgreSql))
                {
                    db.Database.Connection.Open();

                    var databaseName = db.Database.Connection.Database;
                    var serverVersion = db.Database.Connection.ServerVersion;

                    db.Database.Connection.Close();

                    return Text(
                        $"PostgreSQL connection successful.{NL}" +
                        $"Database: {databaseName}{NL}" +
                        $"Server version: {serverVersion}");
                }
            }
            catch (Exception ex)
            {
                return Text("PostgreSQL connection FAILED." + NL + NL + ex);
            }
        }

        public ActionResult Status()
        {
            var sb = new StringBuilder();
            sb.AppendLine($"Configured provider: {DatabaseProviderSettings.Current} ({DatabaseProviderSettings.AppSettingKey})");
            sb.AppendLine($"Auto-migrate on first use: {DatabaseProviderSettings.AutoMigrateEnabled} ({DatabaseProviderSettings.AutoMigrateAppSettingKey})");
            sb.AppendLine();

            foreach (var provider in DatabaseMigrator.AllProviders)
            {
                AppendStatus(sb, provider);
            }

            return Text(sb.ToString());
        }

        public ActionResult Migrate(string provider = "All")
        {
            var providers = ResolveProviders(provider);
            if (providers == null)
            {
                return Text("Unknown provider. Use ?provider=All, ?provider=SqlServer or ?provider=PostgreSql");
            }

            var sb = new StringBuilder();
            foreach (var p in providers)
            {
                sb.AppendLine($"== {p}: applying migrations ==");
                try
                {
                    DatabaseMigrator.MigrateToLatest(p);
                    sb.AppendLine("Migration completed.");
                }
                catch (Exception ex)
                {
                    sb.AppendLine("Migration FAILED: " + ex);
                }

                sb.AppendLine();
                AppendStatus(sb, p);
            }

            return Text(sb.ToString());
        }

        public ActionResult Script(string provider)
        {
            DatabaseProvider p;
            if (!DatabaseProviderSettings.TryParse(provider, out p))
            {
                return Text("Specify ?provider=SqlServer or ?provider=PostgreSql");
            }

            try
            {
                return Text(DatabaseMigrator.ScriptAllMigrations(p));
            }
            catch (Exception ex)
            {
                return Text($"{p}: script generation FAILED: " + ex);
            }
        }

        public ActionResult Customers(string provider = null)
        {
            DatabaseProvider p;
            if (!DatabaseProviderSettings.TryParse(provider, out p))
            {
                p = DatabaseProviderSettings.Current;
            }

            try
            {
                using (var db = new AppDbContext(p))
                {
                    var rows = db.Customers.OrderBy(c => c.Id).ToList();

                    var sb = new StringBuilder();
                    sb.AppendLine($"{p}: {rows.Count} customer(s)");
                    foreach (var c in rows)
                    {
                        sb.AppendLine($"{c.Id}\t{c.FirstName} {c.LastName}\t{c.Email}\t{c.CreatedAt:yyyy-MM-dd HH:mm}\t{(c.IsActive ? "active" : "inactive")}");
                    }

                    return Text(sb.ToString());
                }
            }
            catch (Exception ex)
            {
                return Text($"{p}: query FAILED: " + ex);
            }
        }

        private static IEnumerable<DatabaseProvider> ResolveProviders(string provider)
        {
            if (string.IsNullOrWhiteSpace(provider) || string.Equals(provider.Trim(), "All", StringComparison.OrdinalIgnoreCase))
            {
                return DatabaseMigrator.AllProviders;
            }

            DatabaseProvider p;
            return DatabaseProviderSettings.TryParse(provider, out p) ? new[] { p } : null;
        }

        private static void AppendStatus(StringBuilder sb, DatabaseProvider provider)
        {
            sb.AppendLine($"== {provider} ==");
            try
            {
                var status = DatabaseMigrator.GetStatus(provider);
                sb.AppendLine($"Connection string: {status.ConnectionStringName} (from {SourceOf(provider)})");
                sb.AppendLine($"Database exists:   {status.DatabaseExists}");
                sb.AppendLine($"Up to date:        {status.IsUpToDate}");
                sb.AppendLine($"Local migrations:  {Join(status.Local)}");
                sb.AppendLine($"Applied:           {Join(status.Applied)}");
                sb.AppendLine($"Pending:           {Join(status.Pending)}");
            }
            catch (Exception ex)
            {
                sb.AppendLine("Status FAILED: " + ex);
            }

            sb.AppendLine();
        }

        /// <summary>
        /// Where a provider's connection string came from. The connection string itself is never
        /// shown, because it normally contains a password.
        /// </summary>
        private static string SourceOf(DatabaseProvider provider)
        {
            return DatabaseProviderSettings.IsOverriddenByEnvironment(provider)
                ? "environment variable"
                : "Web.config";
        }

        private static string Join(IEnumerable<string> values)
        {
            var list = values.ToList();
            return list.Count == 0 ? "(none)" : string.Join(", ", list);
        }

        private ContentResult Text(string text)
        {
            return Content(text, "text/plain");
        }
    }
}
