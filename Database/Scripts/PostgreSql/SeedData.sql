-- Sample customers for LegacyDatabaseMigrationPOC (PostgreSQL).
-- Mirrors Migrations\SeedData.cs, which EF runs automatically after migrating.
-- Use this file only when the schema was created from Migrations.sql instead of EF migrations.
-- Idempotent: rows are matched on "Email" and only missing rows are inserted.

INSERT INTO dbo."Customers" ("FirstName", "LastName", "Email", "CreatedAt", "IsActive")
SELECT v."FirstName", v."LastName", v."Email", v."CreatedAt"::timestamp, v."IsActive"
FROM (VALUES
    ('John',    'Smith',    'john.smith@example.com',      '2026-01-10 09:30:00', true),
    ('Sarah',   'Johnson',  'sarah.johnson@example.com',   '2026-01-11 10:15:00', true),
    ('Michael', 'Brown',    'michael.brown@example.com',   '2026-01-12 11:45:00', false),
    ('Emily',   'Davis',    'emily.davis@example.com',     '2026-01-13 14:20:00', true),
    ('David',   'Wilson',   'david.wilson@example.com',    '2026-01-14 16:00:00', true),
    ('Jessica', 'Taylor',   'jessica.taylor@example.com',  '2026-01-15 08:10:00', false),
    ('Daniel',  'Anderson', 'daniel.anderson@example.com', '2026-01-16 12:35:00', true),
    ('Sophia',  'Thomas',   'sophia.thomas@example.com',   '2026-01-17 15:50:00', true),
    ('Robert',  'Jackson',  'robert.jackson@example.com',  '2026-01-18 17:25:00', false),
    ('Olivia',  'White',    'olivia.white@example.com',    '2026-01-19 13:40:00', true)
) AS v ("FirstName", "LastName", "Email", "CreatedAt", "IsActive")
WHERE NOT EXISTS (SELECT 1 FROM dbo."Customers" c WHERE c."Email" = v."Email");

SELECT 'Customers rows: ' || COUNT(*) FROM dbo."Customers";
