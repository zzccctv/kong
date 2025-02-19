return {
  postgres = {
    up = [[
      CREATE INDEX IF NOT EXISTS "acme_storage_ttl_idx" ON "acme_storage" ("ttl");
    ]],
  },
  cassandra = {
    up = "",
  },

  dm = {
    up = [[]],
  },

  highgo = {
    up = [[
      CREATE INDEX IF NOT EXISTS "acme_storage_ttl_idx" ON "acme_storage" ("ttl");
    ]],
  },

  mysql = {
    up = [[]],
  },
}
