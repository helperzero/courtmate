/*
CourtMate for Microsoft SQL Server 2017+
Run after creating and selecting an EMPTY database named CourtMate.
Designed to preserve original React JSON records and Postgres data concepts.
Does not DROP or overwrite any table. Explicit changes require reviewed migrations.
*/
SET XACT_ABORT ON;
GO

IF OBJECT_ID(N'dbo.members', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.members (
    id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_members PRIMARY KEY,
    [name] NVARCHAR(40) NOT NULL,
    gender VARCHAR(1) NOT NULL CONSTRAINT df_members_gender DEFAULT ('M'),
    [level] FLOAT NOT NULL CONSTRAINT df_members_level DEFAULT (3.0),
    phone NVARCHAR(30) NOT NULL CONSTRAINT df_members_phone DEFAULT (N''),
    memo NVARCHAR(300) NOT NULL CONSTRAINT df_members_memo DEFAULT (N''),
    active BIT NOT NULL CONSTRAINT df_members_active DEFAULT (1),
    joined_at DATE NOT NULL CONSTRAINT df_members_joined_at DEFAULT (CONVERT(DATE, GETDATE())),
    created_at DATETIME2(3) NOT NULL CONSTRAINT df_members_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT ck_members_gender CHECK (gender IN ('M','F')),
    CONSTRAINT ck_members_level CHECK ([level] >= 1.0 AND [level] <= 7.0)
  );
END;
GO

IF OBJECT_ID(N'dbo.sessions', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.sessions (
    id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_sessions PRIMARY KEY,
    title NVARCHAR(80) NOT NULL,
    play_date DATE NOT NULL,
    [format] VARCHAR(7) NOT NULL CONSTRAINT df_sessions_format DEFAULT ('doubles'),
    courts INT NOT NULL CONSTRAINT df_sessions_courts DEFAULT (2),
    request_key VARCHAR(80) NULL,
    request_hash VARCHAR(64) NULL,
    created_at DATETIME2(3) NOT NULL CONSTRAINT df_sessions_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT ck_sessions_format CHECK ([format] IN ('doubles','singles')),
    CONSTRAINT ck_sessions_courts CHECK (courts >= 1 AND courts <= 20)
  );
END;
GO

IF OBJECT_ID(N'dbo.matches', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.matches (
    id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_matches PRIMARY KEY,
    session_id INT NOT NULL,
    [round] INT NOT NULL,
    court INT NOT NULL,
    team_a1 INT NOT NULL,
    team_a2 INT NULL,
    team_b1 INT NOT NULL,
    team_b2 INT NULL,
    score_a INT NULL,
    score_b INT NULL,
    score_version INT NOT NULL CONSTRAINT df_matches_score_version DEFAULT (0),
    created_at DATETIME2(3) NOT NULL CONSTRAINT df_matches_created_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT fk_matches_session FOREIGN KEY (session_id) REFERENCES dbo.sessions(id) ON DELETE CASCADE,
    CONSTRAINT fk_matches_team_a1 FOREIGN KEY (team_a1) REFERENCES dbo.members(id),
    CONSTRAINT fk_matches_team_a2 FOREIGN KEY (team_a2) REFERENCES dbo.members(id),
    CONSTRAINT fk_matches_team_b1 FOREIGN KEY (team_b1) REFERENCES dbo.members(id),
    CONSTRAINT fk_matches_team_b2 FOREIGN KEY (team_b2) REFERENCES dbo.members(id),
    CONSTRAINT uq_matches_session_round_court UNIQUE (session_id, [round], court),
    CONSTRAINT ck_matches_round CHECK ([round] >= 1),
    CONSTRAINT ck_matches_court CHECK (court >= 1),
    CONSTRAINT ck_matches_score_version CHECK (score_version >= 0),
    CONSTRAINT ck_matches_score_pair CHECK (
      (score_a IS NULL AND score_b IS NULL)
      OR (score_a IS NOT NULL AND score_b IS NOT NULL
          AND score_a BETWEEN 0 AND 99 AND score_b BETWEEN 0 AND 99)
    )
  );
END;
GO

IF OBJECT_ID(N'dbo.match_score_history', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.match_score_history (
    id INT IDENTITY(1,1) NOT NULL CONSTRAINT pk_match_score_history PRIMARY KEY,
    match_id INT NOT NULL,
    old_score_a INT NULL,
    old_score_b INT NULL,
    new_score_a INT NULL,
    new_score_b INT NULL,
    old_version INT NOT NULL,
    new_version INT NOT NULL,
    changed_at DATETIME2(3) NOT NULL CONSTRAINT df_score_history_changed_at DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT fk_score_history_match FOREIGN KEY (match_id) REFERENCES dbo.matches(id) ON DELETE CASCADE
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.sessions') AND name = N'ux_sessions_request_key')
  CREATE UNIQUE INDEX ux_sessions_request_key ON dbo.sessions(request_key) WHERE request_key IS NOT NULL;
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.sessions') AND name = N'ix_sessions_play_date')
  CREATE INDEX ix_sessions_play_date ON dbo.sessions(play_date DESC, id DESC);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.matches') AND name = N'ix_matches_session_round')
  CREATE INDEX ix_matches_session_round ON dbo.matches(session_id, [round]);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.match_score_history') AND name = N'ix_score_history_match')
  CREATE INDEX ix_score_history_match ON dbo.match_score_history(match_id, changed_at);
GO

PRINT N'CourtMate schema ready.';
GO
