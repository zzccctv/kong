return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "jwt_secrets" (
        "id"              UUID                         PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"     UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"             TEXT                         UNIQUE,
        "secret"          TEXT,
        "algorithm"       TEXT,
        "rsa_public_key"  TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "jwt_secrets_consumer_id_idx" ON "jwt_secrets" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "jwt_secrets_secret_idx" ON "jwt_secrets" ("secret");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS jwt_secrets(
        id             uuid PRIMARY KEY,
        created_at     timestamp,
        consumer_id    uuid,
        algorithm      text,
        rsa_public_key text,
        key            text,
        secret         text
      );
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(key);
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(secret);
      CREATE INDEX IF NOT EXISTS ON jwt_secrets(consumer_id);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "JWT_SECRETS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "consumer_id" varchar2(50),
            "key" varchar2(5000),
            "secret" text,
            "algorithm" text,
            "rsa_public_key" text,
            "tags" text,
            "ws_id" varchar2(50),
            CONSTRAINT "jwt_secrets_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "jwt_secrets_ws_id_key_unique" UNIQUE ("ws_id", "key"),
            CONSTRAINT "jwt_secrets_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "jwt_secrets_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "jwt_secrets_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "jwt_secrets_consumer_id_idx" ON "JWT_SECRETS"("consumer_id" ASC);';


    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "jwt_secrets" (
        "id"              UUID                         PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "consumer_id"     UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "key"             TEXT                         UNIQUE,
        "secret"          TEXT,
        "algorithm"       TEXT,
        "rsa_public_key"  TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "jwt_secrets_consumer_id_idx" ON "jwt_secrets" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "jwt_secrets_secret_idx" ON "jwt_secrets" ("secret");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `jwt_secrets` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `consumer_id` varchar(50) DEFAULT NULL,
        `key` varchar(200) DEFAULT NULL,
        `secret` varchar(200) DEFAULT NULL,
        `algorithm` text,
        `rsa_public_key` text,
        `tags` varchar(200) DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `jwt_secrets_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `jwt_secrets_ws_id_key_unique` (`ws_id`,`key`),
        KEY `jwt_secrets_consumer_id_idx` (`consumer_id`),
        KEY `jwt_secrets_secret_idx` (`secret`),
        KEY `jwtsecrets_tags_idex_tags_idx` (`tags`),
        KEY `jwt_secrets_consumer_id_fkey` (`consumer_id`,`ws_id`),
        CONSTRAINT `jwt_secrets_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `jwt_secrets_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );
    ]],
  },
}
