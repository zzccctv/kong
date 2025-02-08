return {
  postgres = {
    up = [[
      DO $$
      BEGIN
        ALTER TABLE IF EXISTS ONLY "ratelimiting_metrics" ADD "ttl" TIMESTAMP WITH TIME ZONE;
      EXCEPTION WHEN DUPLICATE_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "ratelimiting_metrics_ttl_idx" ON "ratelimiting_metrics" ("ttl");
      EXCEPTION WHEN UNDEFINED_TABLE THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
    ]],
  },

  dm = {
    up = [[]],
  },

  highgo = {
    up = [[
      DO $$
      BEGIN
        ALTER TABLE IF EXISTS ONLY "ratelimiting_metrics" ADD "ttl" TIMESTAMP WITH TIME ZONE;
      EXCEPTION WHEN duplicate_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "ratelimiting_metrics_ttl_idx" ON "ratelimiting_metrics" ("ttl");
      EXCEPTION WHEN undefined_table THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[]],
  },
}
