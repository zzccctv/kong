return {
    postgres = {
      up = [[
        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "services" ADD "enabled" BOOLEAN DEFAULT true;
        EXCEPTION WHEN DUPLICATE_COLUMN THEN
          -- Do nothing, accept existing state
        END;
        $$;
      ]]
    },

    cassandra = {
      up = [[
        ALTER TABLE services ADD enabled boolean;
      ]]
    },

    dm = {
      up = [[]],
    },

    highgo = {
      up = [[
        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "services" ADD "enabled" BOOLEAN DEFAULT true;
        EXCEPTION WHEN duplicate_column THEN
          -- Do nothing, accept existing state
        END;
        $$;
      ]]
    },

    mysql = {
      up = [[]],
    },
  }
