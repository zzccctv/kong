local stringx      = require "pl.stringx"
local logger = require "kong.cmd.utils.log"
local utils        = require "kong.tools.utils"
local fmt          = string.format
local sub          = string.sub
local concat       = table.concat
local insert       = table.insert
local utils_toposort = utils.topological_sort
local error        = error
local update_time  = ngx.update_time
local now          = ngx.now
local log          = ngx.log
local WARN         = ngx.WARN
local DEBUG        = ngx.DEBUG
local timer_every  = ngx.timer.every
local constants = require "kong.constants"
local driver = require "luasql.mysql"
local setmetatable = setmetatable
local pl_stringx = require "pl.stringx"

local SQL_INFORMATION_SCHEMA_TABLES = [[
  SHOW TABLES;
]]

local PROTECTED_TABLES = {
  schema_migrations = true,
  schema_meta = true,
  locks = true,
}

local MYSQLConnector   = {}
MYSQLConnector.__index = MYSQLConnector

local setkeepalive

local function now_updated()
  update_time()
  return now()
end

local function reconnect(config)
  local env = driver.mysql()
  local connection, err = env:connect(config.mysql_database, config.mysql_username,config.mysql_password, config.mysql_host, config.mysql_port)
  if not connection then
    return nil, err
  end
  return connection
end

local function connect(config)
  return kong.vault.try(reconnect, config)
end

setkeepalive = function(connection)
  if not connection then
    return nil, "no active connection"
  end
  return true
end

function MYSQLConnector:escape_identifier(ident)
  return '`' .. (tostring(ident):gsub('"', '""')) .. '`'
end

function MYSQLConnector:escape_literal(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif "boolean" == _exp_0 then
    return val and 1 or 0
  elseif "nil" == _exp_0 then
    return "''"
  elseif ngx.null == val then
    return "''"
  end
  return error("don't know how to escape value: " .. tostring(val) .. " type:" .. _exp_0)
end

local CORE_ENTITIES = constants.CORE_ENTITIES
local get_names_of_tables_with_ttl

do
  local CORE_SCORE = {}
  for _, v in ipairs(CORE_ENTITIES) do
    CORE_SCORE[v] = 1
  end
  CORE_SCORE["workspaces"] = 2


  local function sort_core_tables_first(a, b)
    local sa = CORE_SCORE[a] or 0
    local sb = CORE_SCORE[b] or 0
    if sa == sb then
      -- sort tables in reverse order so that they end up sorted alphabetically,
      -- because utils_topological sort does "dependencies first" and then current.
      return a > b
    end
    return sa < sb
  end

  local sort = table.sort
  get_names_of_tables_with_ttl = function(strategies)
    local s
    local ttl_schemas_by_name = {}
    local table_names = {}
    for _, strategy in pairs(strategies) do
      s = strategy.schema
      if s.ttl then
        table_names[#table_names + 1] = s.name
        ttl_schemas_by_name[s.name] = s
      end
    end

    sort(table_names, sort_core_tables_first)

    local get_table_name_neighbors = function(table_name)
      local neighbors = {}
      local neighbors_len = 0
      local neighbor
      local schema = ttl_schemas_by_name[table_name]

      for _, field in schema:each_field() do
        if field.type == "foreign" and field.schema.ttl then
          neighbor = field.reference
          if ttl_schemas_by_name[neighbor] then -- the neighbor schema name is on table_names
            neighbors_len = neighbors_len + 1
            neighbors[neighbors_len] = neighbor
          end
          -- else the neighbor points to an unknown/uninteresting schema. This happens in tests.
        end
      end

      return neighbors
    end

    local res, err = utils_toposort(table_names, get_table_name_neighbors)

    if res then
      insert(res, 1, "cluster_events")
    end

    return res, err
  end
end

function MYSQLConnector.new(kong_config)
  local self   = {
    config    = kong_config,
    host = kong_config.mysql_host,
    port = kong_config.mysql_port,
    database  = kong_config.mysql_database,
    username  = kong_config.mysql_username,
    password  = kong_config.mysql_password,
    ttl_cleanup_interval = kong_config._debug_pg_ttl_cleanup_interval or 300,
  }
  return setmetatable(self, MYSQLConnector)
end

function MYSQLConnector:init()
  self.major_version       = 5.7
  self.major_minor_version = "5.7"
  return true
end

function MYSQLConnector:init_worker(strategies)
  if ngx.worker.id() == 0 and #kong.configuration.admin_listeners > 0 then
    local table_names = get_names_of_tables_with_ttl(strategies)
    local ttl_escaped = self:escape_identifier("ttl")
    local expire_at_escaped = self:escape_identifier("expire_at")
    local cleanup_statements = {}
    local cleanup_statements_count = #table_names
    for i = 1, cleanup_statements_count do
      local table_name = table_names[i]
      local column_name = table_name == "cluster_events" and expire_at_escaped or ttl_escaped

      cleanup_statements[i] = fmt([[
      DELETE FROM %s WHERE %s < FROM_UNIXTIME(%s) ]], table_name, column_name, "%s")
    end

    return timer_every(self.ttl_cleanup_interval, function(premature)
      if premature then
        return
      end

      -- Fetch the end timestamp from database to avoid problems caused by the difference
      -- between nodes and database time.
      local cleanup_end_timestamp
      local ok, err = self:query("SELECT UNIX_TIMESTAMP(CURRENT_TIMESTAMP) AS now ")
      if not ok then
        log(WARN, "unable to fetch current timestamp from DM database (", err, ")")
        return
      end

      cleanup_end_timestamp = ok[1]["now"]

      for i, statement in ipairs(cleanup_statements) do
        local _tracing_cleanup_start_time = now()
        local ok, err = self:query(fmt(statement, cleanup_end_timestamp))
        if not ok then
          if err then
            log(WARN, "unable to clean expired rows from table '", table_names[i], "' on DM database (", err, ")")

          else
            log(WARN, "unable to clean expired rows from table '", table_names[i], "' on DM database")
          end
        end

        local _tracing_cleanup_end_time = now()
        local time_elapsed = tonumber(fmt("%.3f", _tracing_cleanup_end_time - _tracing_cleanup_start_time))
        log(DEBUG, "cleaning up expired rows from table '", table_names[i], "' took ", time_elapsed, " seconds")
      end
    end)
  end

  return true
end

function MYSQLConnector:infos()
  return {
    strategy    = "MYSQL",
    db_name   = self.database,
    db_desc     = "database",
    db_ver      = "5.7",
  }
end

function MYSQLConnector:connect()
  local conn = self:get_stored_connection()
  if conn then
    return conn
  end

  local connection, err = connect(self.config)
  if not connection then
    return nil, err
  end

  self:store_connection(connection)

  return connection
end

function MYSQLConnector:connect_migrations()
  return self:connect()
end

function MYSQLConnector:setkeepalive()
  local conn = self:get_stored_connection()
  if not conn then
    return true
  end

  local _, err = setkeepalive(conn)

  self:store_connection(nil)

  if err then
    return nil, err
  end

  return true
end

function MYSQLConnector:close()
  local conn = self:get_stored_connection()
  if not conn then
    return true
  end

  local _, err = conn:close()

  self:store_connection(nil)

  if err then
    return nil, err
  end

  return true
end

function MYSQLConnector:query(sql, operation)
  local conn = self:get_stored_connection()
  local flag = false
  if not conn then
    local err
    conn, err = connect(self.config)
    if not conn then
      return nil, err
    end
    flag = true
  end

  local t_cql = pl_stringx.split(sql, ";")
  local res, err

  if #t_cql == 1 then
    -- TODO: prepare queries
    res, err = conn:execute(sql)
  else
    for i = 1, #t_cql do
      local cql = pl_stringx.strip(t_cql[i])
      if cql ~= "" then
        res, err = conn:execute(cql)
        if not res then
          break
        end
      end
    end
  end

  if err then
    return nil, err
  end

  if type(res) == "userdata" then
    local rows = {}
    local row = res:fetch({}, "a")
    while row do
      insert(rows, row)
      row = res:fetch({}, "a")
    end
    if flag then
      --需要优化成数据库连接池
      conn:close()
    end
    return rows
  end
  if flag then
    conn:close()
  end
  return res
end

local function iterator(rows)
  local i = 0
  return function()
    i = i + 1
    return rows[i]
  end
end

function MYSQLConnector:iterate(sql)
  local res, err = self:query(sql)
  if err then
    return nil, err
  end
  return iterator(res)
end

local function get_table_names(self, excluded)
  local i = 0
  local table_names = {}
  for row, err in self:iterate(SQL_INFORMATION_SCHEMA_TABLES) do
    if err then
      return nil, err
    end

    for _, value in pairs(row) do
      if not excluded or not excluded[value] then
        i = i + 1
        table_names[i] = self:escape_identifier(value)
      end
    end
  end

  return table_names
end

function MYSQLConnector:truncate()
  local table_names, err = get_table_names(self, PROTECTED_TABLES)
  if not table_names then
    return nil, err
  end

  if #table_names == 0 then
    return true
  end

  local truncate_statement = concat {
    "TRUNCATE TABLE ", concat(table_names, ", ")
  }

  local ok, err = self:query(truncate_statement)
  if not ok then
    return nil, err
  end

  return true
end

function MYSQLConnector:truncate_table(table_name)
  local truncate_statement = concat {
    "TRUNCATE TABLE ", self:escape_identifier(table_name)
  }

  local ok, err = self:query(truncate_statement)
  if not ok then
    return nil, err
  end

  return true
end

function MYSQLConnector:setup_locks(_, _)
  logger.debug("creating 'locks' table if not existing...")
  local ok, err = self:query([[
     CREATE TABLE  IF NOT EXISTS `locks` (
      `key` varchar(50) NOT NULL,
      `owner` text,
      `ttl` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
      PRIMARY KEY (`key`),
      KEY `locks_ttl_idx` (`ttl`)
    );
  ]])

  if not ok then
    return nil, err
  end

  logger.debug("successfully created 'locks' table")

  return true
end

function MYSQLConnector:insert_lock(key, ttl, owner)
  local ttl_escaped = concat {
    "FROM_UNIXTIME(",
    self:escape_literal(tonumber(fmt("%.3f", now_updated() + ttl))),
    ")"
  }

  local sql = concat { "DELETE FROM locks\n",
                       "      WHERE ttl < CURRENT_TIMESTAMP;\n",
                       "INSERT INTO locks (`key`, `owner`, ttl)\n",
                       "     VALUES (", self:escape_literal(key), ", ",
                       self:escape_literal(owner), ", ",
                       ttl_escaped, ");"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end
  return true
end

function MYSQLConnector:read_lock(key)
  local sql = concat {
    "SELECT *\n",
    "  FROM locks\n",
    " WHERE `key` `= ", self:escape_literal(key), "\n",
    "   AND ttl >= CURRENT_TIMESTAMP\n",
    " LIMIT 1;"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return res[1] ~= nil
end

function MYSQLConnector:remove_lock(key, owner)
  local sql = concat {
    "DELETE FROM locks\n",
    "      WHERE `key`   = ", self:escape_literal(key), "\n",
    "   AND `owner` = ", self:escape_literal(owner), ";"
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return true
end

function MYSQLConnector:schema_migrations()
  local conn = self:get_stored_connection()
  if not conn then
    error("no connection")
  end

  local table_names, err = get_table_names(self)
  if not table_names then
    return nil, err
  end

  local schema_meta_table_name = self:escape_identifier("schema_meta")
  local schema_meta_table_exists
  for _, table_name in ipairs(table_names) do
    if table_name == schema_meta_table_name then
      schema_meta_table_exists = true
      break
    end
  end

  if not schema_meta_table_exists then
    -- database, but no schema_meta: needs bootstrap
    return nil
  end

  local rows, err = self:query(concat({
    "SELECT *\n",
    "  FROM schema_meta\n",
    " WHERE `key` = ",  self:escape_literal("schema_meta"), ";"
  }), "read")

  if not rows then
    return nil, err
  end

  for _, row in ipairs(rows) do
    row.executed = self:unserialize(row.executed)
    row.pending = self:unserialize(row.pending)
    if row.pending == null then
      row.pending = nil
    end

  end

  -- no migrations: is bootstrapped but not migrated
  -- migrations: has some migrations
  return rows
end

function MYSQLConnector:unserialize(lua)
  local t = type(lua)
  if t == "nil" or lua == "" then
    return nil
  elseif t == "number" or t == "string" or t == "boolean" then
    lua = tostring(lua)
  else
    error("can not unserialize a " .. t .. " type.")
  end
  lua = "return " .. lua
  local func = loadstring(lua)
  if func == nil then
    return nil
  end
  return func()
end

function MYSQLConnector:schema_bootstrap(kong_config, default_locks_ttl)
  local conn = self:get_stored_connection()
  if not conn then
    error("no connection")
  end

  local res, err = self:query([[
       CREATE TABLE  IF NOT EXISTS `schema_meta` (
        `key` varchar(50) NOT NULL,
        `subsystem` varchar(200) NOT NULL,
        `last_executed` text,
        `executed` text,
        `pending` text,
        PRIMARY KEY (`key`,`subsystem`)
      )
    ]])

  if not res then
    return nil, err
  end

  logger.debug("successfully created 'schema_meta' table")

  local ok
  ok, err = self:setup_locks(default_locks_ttl, true)
  if not ok then
    return nil, err
  end

  return true
end

function MYSQLConnector:schema_reset()

end

function MYSQLConnector:run_up_migration(name, up_sql)
  if type(name) ~= "string" then
    error("name must be a string", 2)
  end

  if type(up_sql) ~= "string" then
    error("up_sql must be a string", 2)
  end

  local conn = self:get_stored_connection()
  if not conn then
    error("no connection")
  end

  local sql = stringx.strip(up_sql)
  if sub(sql, -1) ~= ";" then
    sql = sql .. ";"
  end

  local sql = concat {
    sql, "\n",
  }

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return true
end

function MYSQLConnector:record_migration(subsystem, name, state)
  if type(subsystem) ~= "string" then
    error("subsystem must be a string", 2)
  end

  if type(name) ~= "string" then
    error("name must be a string", 2)
  end

  local conn = self:get_stored_connection()
  if not conn then
    error("no connection")
  end

  local key_escaped  = self:escape_literal("schema_meta")
  local subsystem_escaped = self:escape_literal(subsystem)
  local name_escaped = self:escape_literal(name)
  local sql
  if state == "executed" then
    sql = concat({
      "INSERT INTO schema_meta (`key`, subsystem, last_executed, executed)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped, ", ", name_escaped, ", ",  "'{'",name_escaped,"'}'", ")\n",
      "ON DUPLICATE KEY UPDATE\n",
      "        last_executed = ",name_escaped,",\n",
      "        executed = REPLACE(executed,'}',','",name_escaped,"'}');",
    })
  elseif state == "pending" then
    sql = concat({
      "INSERT INTO schema_meta (`key`, subsystem, pending)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped,  ", ",  "'{'",name_escaped,"'}'", ")\n",
      "ON DUPLICATE KEY UPDATE\n",
      "        pending = REPLACE(pending,'}',','",name_escaped,"'}');",
    })
  elseif state == "teardown" then
    sql = concat({
      "INSERT INTO schema_meta (`key`, subsystem, last_executed, executed)\n",
      "     VALUES (", key_escaped, ", ", subsystem_escaped, ", ", name_escaped, ", ",  "'{'",name_escaped,"'}'", ")\n",
      "ON DUPLICATE KEY UPDATE\n",
      "        last_executed = ",name_escaped,",\n",
      "        executed = REPLACE(executed,'}',','",name_escaped,"'}'),\n",
      "        pending = REPLACE(pending,'}',','",name_escaped,"'}');",
    })
  else
    error("unknown 'state' argument: " .. tostring(state))
  end

  local res, err = self:query(sql)
  if not res then
    return nil, err
  end

  return true
end

return MYSQLConnector
