return {
  postgres = {
    up = [[
      DROP TRIGGER IF EXISTS "sessions_ttl_trigger" ON "sessions";

      DO $$
      BEGIN
        CREATE TRIGGER "sessions_ttl_trigger"
        AFTER INSERT ON "sessions"
        FOR EACH STATEMENT
        EXECUTE PROCEDURE batch_delete_expired_rows("ttl");
      EXCEPTION WHEN UNDEFINED_COLUMN OR UNDEFINED_TABLE THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[]],
  },

  dm = {
    up = [[]],
  },

  highgo = {
    up = [[
      DROP TRIGGER IF EXISTS "sessions_ttl_trigger" ON "sessions";

      DO $$
      BEGIN
        CREATE TRIGGER "sessions_ttl_trigger"
        AFTER INSERT ON "sessions"
        FOR EACH STATEMENT
        EXECUTE PROCEDURE batch_delete_expired_rows("ttl");
      EXCEPTION WHEN undefined_column or undefined_table THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[]],
  },
}
