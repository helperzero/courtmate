/* DBA optional bootstrap. Review target server before execution. */
IF DB_ID(N'CourtMate') IS NULL
BEGIN
  CREATE DATABASE CourtMate;
END;
GO
