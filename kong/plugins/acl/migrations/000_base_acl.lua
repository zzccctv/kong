return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acls" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "group"        TEXT,
        "cache_key"    TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "acls_consumer_id_idx" ON "acls" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "acls_group_idx" ON "acls" ("group");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS acls(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        group       text,
        cache_key   text
      );
      CREATE INDEX IF NOT EXISTS ON acls(group);
      CREATE INDEX IF NOT EXISTS ON acls(consumer_id);
      CREATE INDEX IF NOT EXISTS ON acls(cache_key);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "ACLS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "consumer_id" varchar2(50),
            "group" text,
            "cache_key" varchar2(500),
            "tags" text,
            "ws_id" varchar2(50),
            CONSTRAINT "acls_cache_key_key" UNIQUE ("cache_key"),
            CONSTRAINT "acls_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "acls_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "acls_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "acls_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "acls_consumer_id_idx" ON "ACLS"("consumer_id" ASC);';

    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acls" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "group"        TEXT,
        "cache_key"    TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "acls_consumer_id_idx" ON "acls" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "acls_group_idx" ON "acls" ("group");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `acls` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `consumer_id` varchar(50) DEFAULT NULL,
        `group` varchar(200) DEFAULT NULL,
        `cache_key` varchar(200) DEFAULT NULL,
        `tags` varchar(200) DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `acls_cache_key_key` (`cache_key`),
        UNIQUE KEY `acls_id_ws_id_unique` (`id`,`ws_id`),
        KEY `acls_consumer_id_idx` (`consumer_id`) USING BTREE,
        KEY `acls_group_idx` (`group`) USING BTREE,
        KEY `acls_tags_idex_tags_idx` (`tags`) USING BTREE,
        KEY `acls_consumer_id_fkey` (`consumer_id`,`ws_id`),
        KEY `acls_ws_id_fkey` (`ws_id`),
        CONSTRAINT `acls_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `acls_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );
    ]],
  },
}
