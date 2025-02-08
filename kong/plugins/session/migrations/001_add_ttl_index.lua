return {
  postgres = {
    up = [[
      CREATE INDEX IF NOT EXISTS sessions_ttl_idx ON sessions (ttl);
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
      CREATE INDEX IF NOT EXISTS sessions_ttl_idx ON sessions (ttl);
    ]],
  },

  mysql = {
    up = [[]],
  },
}
