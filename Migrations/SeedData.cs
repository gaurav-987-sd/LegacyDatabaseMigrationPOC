using System;
using System.Data.Entity.Migrations;
using LegacyDatabaseMigrationPOC.Data;
using LegacyDatabaseMigrationPOC.Models;

namespace LegacyDatabaseMigrationPOC.Migrations
{
    /// <summary>
    /// Sample rows applied after migrating to the latest version, for every provider, so a
    /// freshly set up SQL Server and PostgreSQL database hold identical data.
    /// Rows are matched on Email, so re-running is idempotent.
    /// </summary>
    internal static class SeedData
    {
        public static void Apply(AppDbContext context)
        {
            context.Customers.AddOrUpdate(
                c => c.Email,
                Customer("John", "Smith", "john.smith@example.com", new DateTime(2026, 1, 10, 9, 30, 0), true),
                Customer("Sarah", "Johnson", "sarah.johnson@example.com", new DateTime(2026, 1, 11, 10, 15, 0), true),
                Customer("Michael", "Brown", "michael.brown@example.com", new DateTime(2026, 1, 12, 11, 45, 0), false),
                Customer("Emily", "Davis", "emily.davis@example.com", new DateTime(2026, 1, 13, 14, 20, 0), true),
                Customer("David", "Wilson", "david.wilson@example.com", new DateTime(2026, 1, 14, 16, 0, 0), true),
                Customer("Jessica", "Taylor", "jessica.taylor@example.com", new DateTime(2026, 1, 15, 8, 10, 0), false),
                Customer("Daniel", "Anderson", "daniel.anderson@example.com", new DateTime(2026, 1, 16, 12, 35, 0), true),
                Customer("Sophia", "Thomas", "sophia.thomas@example.com", new DateTime(2026, 1, 17, 15, 50, 0), true),
                Customer("Robert", "Jackson", "robert.jackson@example.com", new DateTime(2026, 1, 18, 17, 25, 0), false),
                Customer("Olivia", "White", "olivia.white@example.com", new DateTime(2026, 1, 19, 13, 40, 0), true));

            context.SaveChanges();
        }

        private static Customer Customer(string firstName, string lastName, string email, DateTime createdAt, bool isActive)
        {
            return new Customer
            {
                FirstName = firstName,
                LastName = lastName,
                Email = email,
                CreatedAt = createdAt,
                IsActive = isActive
            };
        }
    }
}
