return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "hmacauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "username"     TEXT                         UNIQUE,
        "secret"       TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "hmacauth_credentials_consumer_id_idx" ON "hmacauth_credentials" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS hmacauth_credentials(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        consumer_id uuid,
        username    text,
        secret      text
      );
      CREATE INDEX IF NOT EXISTS ON hmacauth_credentials(username);
      CREATE INDEX IF NOT EXISTS ON hmacauth_credentials(consumer_id);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "HMACAUTH_CREDENTIALS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "consumer_id" varchar2(50),
            "username" varchar2(500),
            "secret" text,
            "tags" text,
            "ws_id" varchar2(50),
            CONSTRAINT "hmacauth_credentials_ws_id_username_unique" UNIQUE ("ws_id", "username"),
            CONSTRAINT "hmacauth_credentials_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "hmacauth_credentials_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "hmacauth_credentials_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "hmacauth_credentials_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "hmacauth_credentials_consumer_id_idx" ON "HMACAUTH_CREDENTIALS"("consumer_id" ASC);';


    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "hmacauth_credentials" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "username"     TEXT                         UNIQUE,
        "secret"       TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "hmacauth_credentials_consumer_id_idx" ON "hmacauth_credentials" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `hmacauth_credentials` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `consumer_id` varchar(50) DEFAULT NULL,
        `username` varchar(200) DEFAULT NULL,
        `secret` text,
        `tags` varchar(200) DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `hmacauth_credentials_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `hmacauth_credentials_ws_id_username_unique` (`ws_id`,`username`),
        KEY `hmacauth_credentials_consumer_id_idx` (`consumer_id`),
        KEY `hmacauth_tags_idex_tags_idx` (`tags`),
        KEY `hmacauth_credentials_consumer_id_fkey` (`consumer_id`,`ws_id`),
        CONSTRAINT `hmacauth_credentials_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `hmacauth_credentials_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );
    ]],
  },
}
