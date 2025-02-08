return {
  name = "migration",
  fields = {
    { name      = { type = "string", required = true } },
    {
      postgres  = {
        type = "record", required = true,
        fields = {
          { up = { type = "string", len_min = 0 } },
          { up_f = { type = "function" } },
          { teardown = { type = "function" } },
        },
      },
    },
    {
      cassandra = {
        type = "record", required = true,
        fields = {
          { up = { type = "string", len_min = 0 } },
          { up_f = { type = "function" } },
          { teardown = { type = "function" } },
        },
      }
    },
    {
      dm = {
        type = "record", required = true,
        fields = {
          { up = { type = "string", len_min = 0 } },
          { up_f = { type = "function" } },
          { teardown = { type = "function" } },
        },
      }
    },
    {
      highgo = {
        type = "record", required = true,
        fields = {
          { up = { type = "string", len_min = 0 } },
          { up_f = { type = "function" } },
          { teardown = { type = "function" } },
        },
      }
    },
    {
      mysql = {
        type = "record", required = true,
        fields = {
          { up = { type = "string", len_min = 0 } },
          { up_f = { type = "function" } },
          { teardown = { type = "function" } },
        },
      }
    },
  },
  entity_checks = {
    {
      at_least_one_of = {
        "postgres.up", "postgres.up_f", "postgres.teardown",
        "cassandra.up", "cassandra.up_f", "cassandra.teardown",
        "dm.up", "dm.up_f", "dm.teardown",
        "highgo.up", "highgo.up_f", "highgo.teardown",
        "mysql.up", "mysql.up_f", "mysql.teardown",
      },
    },
  },
}
