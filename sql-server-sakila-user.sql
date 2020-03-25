USE [master]
GO

CREATE LOGIN [sakila] WITH PASSWORD=N'p_ssW0rd', DEFAULT_DATABASE=[sakila]
GO
ALTER SERVER ROLE [sysadmin] ADD MEMBER [sakila]
GO


USE [sakila]
GO
CREATE USER [sakila] FOR LOGIN [sakila]
GO
ALTER USER [sakila] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [sakila]
GO
