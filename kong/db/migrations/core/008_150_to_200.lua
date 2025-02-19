return {
  postgres = {
    up = [[
      ALTER TABLE IF EXISTS ONLY "routes" ALTER COLUMN "path_handling" SET DEFAULT 'v0';
    ]],

    teardown = function(connector)
      local _, err = connector:query([[
        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "plugins" DROP COLUMN "run_on";
        EXCEPTION WHEN UNDEFINED_COLUMN THEN
          -- Do nothing, accept existing state
        END;
        $$;


        DO $$
        BEGIN
          DROP TABLE IF EXISTS "cluster_ca";
        END;
        $$;
      ]])

      if err then
        return nil, err
      end

      return true
    end,
  },

  cassandra = {
    up = [[
    ]],

    teardown = function(connector)
      local coordinator = assert(connector:get_stored_connection())
      local _, err = coordinator:execute("DROP INDEX IF EXISTS plugins_run_on_idx")
      if err then
        return nil, err
      end

      _, err = coordinator:execute("DROP TABLE IF EXISTS cluster_ca")
      if err then
        return nil, err
      end

      -- no need to drop the actual column from the database
      -- (this operation is not reentrant in Cassandra)
      --[===[
      assert(coordinator:execute("ALTER TABLE plugins DROP run_on"))
      ]===]

      return true
    end,
  },

  dm = {
    up = [[]],
  },

  highgo = {
    up = [[
      ALTER TABLE IF EXISTS ONLY "routes" ALTER COLUMN "path_handling" SET DEFAULT 'v0';
    ]],

    teardown = function(connector)
      local _, err = connector:query([[
        DO $$
        BEGIN
          ALTER TABLE IF EXISTS ONLY "plugins" DROP COLUMN "run_on";
        EXCEPTION WHEN undefined_column THEN
          -- Do nothing, accept existing state
        END;
        $$;


        DO $$
        BEGIN
          DROP TABLE IF EXISTS "cluster_ca";
        END;
        $$;
      ]])

      if err then
        return nil, err
      end

      return true
    end,
  },

  mysql = {
    up = [[]],
  },
}
