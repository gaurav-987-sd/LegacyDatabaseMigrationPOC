-- Sample customers for LegacyDatabaseMigrationPOC (SQL Server).
-- Mirrors Migrations\SeedData.cs, which EF runs automatically after migrating.
-- Use this file only when the schema was created from Migrations.sql instead of EF migrations.
-- Idempotent: rows are matched on Email and only missing rows are inserted.
SET NOCOUNT ON;

MERGE dbo.Customers AS target
USING (VALUES
    (N'John',    N'Smith',    N'john.smith@example.com',      '2026-01-10T09:30:00', 1),
    (N'Sarah',   N'Johnson',  N'sarah.johnson@example.com',   '2026-01-11T10:15:00', 1),
    (N'Michael', N'Brown',    N'michael.brown@example.com',   '2026-01-12T11:45:00', 0),
    (N'Emily',   N'Davis',    N'emily.davis@example.com',     '2026-01-13T14:20:00', 1),
    (N'David',   N'Wilson',   N'david.wilson@example.com',    '2026-01-14T16:00:00', 1),
    (N'Jessica', N'Taylor',   N'jessica.taylor@example.com',  '2026-01-15T08:10:00', 0),
    (N'Daniel',  N'Anderson', N'daniel.anderson@example.com', '2026-01-16T12:35:00', 1),
    (N'Sophia',  N'Thomas',   N'sophia.thomas@example.com',   '2026-01-17T15:50:00', 1),
    (N'Robert',  N'Jackson',  N'robert.jackson@example.com',  '2026-01-18T17:25:00', 0),
    (N'Olivia',  N'White',    N'olivia.white@example.com',    '2026-01-19T13:40:00', 1)
) AS source (FirstName, LastName, Email, CreatedAt, IsActive)
ON target.Email = source.Email
WHEN NOT MATCHED THEN
    INSERT (FirstName, LastName, Email, CreatedAt, IsActive)
    VALUES (source.FirstName, source.LastName, source.Email, CAST(source.CreatedAt AS datetime), source.IsActive);

DECLARE @rows int = (SELECT COUNT(*) FROM dbo.Customers);
PRINT CONCAT('Customers rows: ', @rows);
