-- Runtime: (re)create the server-level [sakila] login and the database user
-- after the restore. The login lives in master (not in a database backup), so
-- it must be recreated on each start; guarded with IF NOT EXISTS so it is
-- idempotent across container restarts.
USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'sakila')
  CREATE LOGIN [sakila] WITH PASSWORD=N'p_ssW0rd', DEFAULT_DATABASE=[sakila]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [sakila]
GO


USE [sakila]
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'sakila')
  CREATE USER [sakila] FOR LOGIN [sakila]
GO
ALTER USER [sakila] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [sakila]
GO

SELECT 'sakiladb/sqlserver has successfully initialized.' AS sakiladb_completion_message
GO
