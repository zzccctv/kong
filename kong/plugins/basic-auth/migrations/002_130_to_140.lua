return {
  postgres = {
    up = [[
      DO $$
      BEGIN
        ALTER TABLE IF EXISTS ONLY basicauth_credentials ADD tags TEXT[];
      EXCEPTION WHEN DUPLICATE_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS basicauth_tags_idex_tags_idx ON basicauth_credentials USING GIN(tags);
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DROP TRIGGER IF EXISTS basicauth_sync_tags_trigger ON basicauth_credentials;

      DO $$
      BEGIN
        CREATE TRIGGER basicauth_sync_tags_trigger
        AFTER INSERT OR UPDATE OF tags OR DELETE ON basicauth_credentials
        FOR EACH ROW
        EXECUTE PROCEDURE sync_tags();
      EXCEPTION WHEN UNDEFINED_COLUMN OR UNDEFINED_TABLE THEN
        -- Do nothing, accept existing state
      END$$;

    ]],
  },
  cassandra = {
    up = [[
      ALTER TABLE basicauth_credentials ADD tags set<text>;
    ]],
  },

  dm = {
    up = [[]],
  },

  highgo = {
    up = [[
      DO $$
      BEGIN
        ALTER TABLE IF EXISTS ONLY basicauth_credentials ADD tags TEXT[];
      EXCEPTION WHEN duplicate_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS basicauth_tags_idex_tags_idx ON basicauth_credentials USING gin(tags);
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DROP TRIGGER IF EXISTS basicauth_sync_tags_trigger ON basicauth_credentials;

      DO $$
      BEGIN
        CREATE TRIGGER basicauth_sync_tags_trigger
        AFTER INSERT OR UPDATE OF tags OR DELETE ON basicauth_credentials
        FOR EACH ROW
        EXECUTE PROCEDURE sync_tags();
      EXCEPTION WHEN undefined_column or undefined_table THEN
        -- Do nothing, accept existing state
      END$$;

    ]],
  },

  mysql = {
    up = [[]],
  },
}
