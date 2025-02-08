return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS sessions(
        id            uuid,
        session_id    text UNIQUE,
        expires       int,
        data          text,
        created_at    timestamp WITH TIME ZONE,
        ttl           timestamp WITH TIME ZONE,
        PRIMARY KEY (id)
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "session_sessions_expires_idx" ON "sessions" ("expires");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },
  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS sessions(
        id            uuid,
        session_id    text,
        expires       int,
        data          text,
        created_at    timestamp,
        PRIMARY KEY (id)
      );

      CREATE INDEX IF NOT EXISTS ON sessions (session_id);
      CREATE INDEX IF NOT EXISTS ON sessions (expires);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "SESSIONS" (
            "id" varchar2(50) NOT NULL,
            "session_id" varchar2(50),
            "expires" integer,
            "data" text,
            "created_at" timestamp(6),
            "ttl" timestamp(6),
            CONSTRAINT "sessions_session_id_key" UNIQUE ("session_id"),
            CONSTRAINT "sessions_pkey" PRIMARY KEY ("id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "session_sessions_expires_idx" ON "SESSIONS"("expires" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "sessions_ttl_idx" ON "SESSIONS"("ttl" ASC);';

          execute immediate 'CREATE TRIGGER sessions_ttl_trigger
          AFTER INSERT ON "SESSIONS"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from SESSIONS where rowid in (select rowid from  SESSIONS where "ttl" < CURRENT_TIMESTAMP)'';
          END;';

    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS sessions(
        id            uuid,
        session_id    text UNIQUE,
        expires       int,
        data          text,
        created_at    timestamp WITH TIME ZONE,
        ttl           timestamp WITH TIME ZONE,
        PRIMARY KEY (id)
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "session_sessions_expires_idx" ON "sessions" ("expires");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `sessions` (
        `id` varchar(50) NOT NULL,
        `session_id` varchar(50) DEFAULT NULL,
        `expires` int(11) DEFAULT NULL,
        `data` text,
        `created_at` timestamp(6) NULL DEFAULT NULL,
        `ttl` timestamp(6) NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `sessions_session_id_key` (`session_id`),
        KEY `session_sessions_expires_idx` (`expires`),
        KEY `sessions_ttl_idx` (`ttl`)
      );
    ]],
  },
}
