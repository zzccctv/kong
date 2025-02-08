return {
  postgres = {
    up = [[
      -- Unique constraint on "name" already adds btree index
      DROP INDEX IF EXISTS "workspaces_name_idx";
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
      -- Unique constraint on "name" already adds btree index
      DROP INDEX IF EXISTS "workspaces_name_idx";
    ]],
  },

  mysql = {
    up = [[]],
  },
}
