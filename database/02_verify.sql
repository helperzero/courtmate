/* Run in the CourtMate database to inspect tables and constraints. */
SELECT t.name AS table_name, COUNT(c.column_id) AS column_count
FROM sys.tables t INNER JOIN sys.columns c ON c.object_id = t.object_id
WHERE t.name IN ('members', 'sessions', 'matches', 'match_score_history')
GROUP BY t.name ORDER BY t.name;

SELECT 'members' AS entity, COUNT(*) AS total FROM dbo.members
UNION ALL SELECT 'sessions', COUNT(*) FROM dbo.sessions
UNION ALL SELECT 'matches', COUNT(*) FROM dbo.matches
UNION ALL SELECT 'match_score_history', COUNT(*) FROM dbo.match_score_history;

SELECT 'duplicate_court' AS problem, COUNT(*) AS violations
FROM (
  SELECT session_id, [round], court
  FROM dbo.matches
  GROUP BY session_id, [round], court
  HAVING COUNT(*) > 1
) d;
