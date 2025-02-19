return {
    postgres = {
      up = [[
        DO $$
            BEGIN
            ALTER TABLE IF EXISTS ONLY "plugins" ADD "instance_name" TEXT;
            ALTER TABLE IF EXISTS ONLY "plugins" ADD CONSTRAINT "plugins_ws_id_instance_name_unique" UNIQUE ("ws_id", "instance_name");
            EXCEPTION WHEN DUPLICATE_COLUMN THEN
            -- Do nothing, accept existing state
            END;
        $$;
      ]]
    },

    cassandra = {
      up = [[
        ALTER TABLE plugins ADD instance_name text;
        CREATE INDEX IF NOT EXISTS plugins_ws_id_instance_name_idx ON plugins(instance_name);
      ]]
    },

    dm = {
      up = [[]],
    },

    highgo = {
      up = [[
        DO $$
            BEGIN
            ALTER TABLE IF EXISTS ONLY "plugins" ADD "instance_name" TEXT;
            ALTER TABLE IF EXISTS ONLY "plugins" ADD CONSTRAINT "plugins_ws_id_instance_name_unique" UNIQUE ("ws_id", "instance_name");
            exception when duplicate_column then
            -- Do nothing, accept existing state
            END;
        $$;
      ]]
    },

    mysql = {
      up = [[]],
    },
  }
