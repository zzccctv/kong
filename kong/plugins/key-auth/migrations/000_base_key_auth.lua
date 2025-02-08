return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "keyauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"          TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "keyauth_credentials_consumer_id_idx" ON "keyauth_credentials" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS keyauth_credentials(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        key         text
      );
      CREATE INDEX IF NOT EXISTS ON keyauth_credentials(key);
      CREATE INDEX IF NOT EXISTS ON keyauth_credentials(consumer_id);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "KEYAUTH_CREDENTIALS" (
            "id"  varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "consumer_id"  varchar2(50),
            "key" varchar2(500),
            "tags" text,
            "ttl" timestamp(6),
            "ws_id"  varchar2(50),
            CONSTRAINT "keyauth_credentials_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "keyauth_credentials_ws_id_key_unique" UNIQUE ("ws_id", "key"),
            CONSTRAINT "keyauth_credentials_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "keyauth_credentials_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "keyauth_credentials_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "keyauth_credentials_consumer_id_idx" ON "KEYAUTH_CREDENTIALS"("consumer_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "keyauth_credentials_ttl_idx" ON "KEYAUTH_CREDENTIALS"("ttl" ASC);';

          execute immediate 'CREATE TRIGGER keyauth_credentials_ttl_trigger
          AFTER INSERT ON "KEYAUTH_CREDENTIALS"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from KEYAUTH_CREDENTIALS where rowid in (select rowid from  KEYAUTH_CREDENTIALS where "ttl" < CURRENT_TIMESTAMP)'';
          END;';
    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "keyauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"          TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "keyauth_credentials_consumer_id_idx" ON "keyauth_credentials" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `keyauth_credentials` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `consumer_id` varchar(50) DEFAULT NULL,
        `key` varchar(200) DEFAULT NULL,
        `tags` varchar(200) DEFAULT NULL,
        `ttl` timestamp(6) NULL DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `keyauth_credentials_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `keyauth_credentials_ws_id_key_unique` (`ws_id`,`key`),
        KEY `keyauth_credentials_consumer_id_idx` (`consumer_id`),
        KEY `keyauth_credentials_ttl_idx` (`ttl`),
        KEY `keyauth_tags_idex_tags_idx` (`tags`),
        KEY `keyauth_credentials_consumer_id_fkey` (`consumer_id`,`ws_id`),
        CONSTRAINT `keyauth_credentials_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `keyauth_credentials_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );
    ]],
  },
}
