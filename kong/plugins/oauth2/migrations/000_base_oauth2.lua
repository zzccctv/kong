return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "oauth2_credentials" (
        "id"             UUID                         PRIMARY KEY,
        "created_at"     TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"           TEXT,
        "consumer_id"    UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "client_id"      TEXT                         UNIQUE,
        "client_secret"  TEXT,
        "redirect_uris"  TEXT[]
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_consumer_id_idx" ON "oauth2_credentials" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_secret_idx" ON "oauth2_credentials" ("client_secret");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_authorization_codes" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "code"                  TEXT                         UNIQUE,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT,
        "ttl"                   TIMESTAMP WITH TIME ZONE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_codes_authenticated_userid_idx" ON "oauth2_authorization_codes" ("authenticated_userid");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_credential_id_idx"
                                ON "oauth2_authorization_codes" ("credential_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_service_id_idx"
                                ON "oauth2_authorization_codes" ("service_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_tokens" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "access_token"          TEXT                         UNIQUE,
        "refresh_token"         TEXT                         UNIQUE,
        "token_type"            TEXT,
        "expires_in"            INTEGER,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT,
        "ttl"                   TIMESTAMP WITH TIME ZONE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_authenticated_userid_idx" ON "oauth2_tokens" ("authenticated_userid");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_credential_id_idx"
                                ON "oauth2_tokens" ("credential_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_service_id_idx"
                                ON "oauth2_tokens" ("service_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS oauth2_credentials(
        id            uuid PRIMARY KEY,
        created_at    timestamp,
        consumer_id   uuid,
        client_id     text,
        client_secret text,
        name          text,
        redirect_uris set<text>
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(consumer_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_credentials(client_secret);



      CREATE TABLE IF NOT EXISTS oauth2_authorization_codes(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        credential_id        uuid,
        authenticated_userid text,
        code                 text,
        scope                text
      ) WITH default_time_to_live = 300;
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(code);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_authorization_codes(authenticated_userid);



      CREATE TABLE IF NOT EXISTS oauth2_tokens(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        service_id           uuid,
        credential_id        uuid,
        access_token         text,
        authenticated_userid text,
        refresh_token        text,
        scope                text,
        token_type           text,
        expires_in           int
      );
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(service_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(access_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(refresh_token);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(credential_id);
      CREATE INDEX IF NOT EXISTS ON oauth2_tokens(authenticated_userid);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "OAUTH2_CREDENTIALS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "name" text,
            "consumer_id" varchar2(50),
            "client_id" varchar2(500),
            "client_secret" text,
            "redirect_uris" text,
            "tags" text,
            "client_type" text,
            "hash_secret" number(1,0),
            "ws_id" varchar2(50),
          CONSTRAINT "oauth2_credentials_id_ws_id_unique" UNIQUE ("id", "ws_id"),
          CONSTRAINT "oauth2_credentials_ws_id_client_id_unique" UNIQUE ("ws_id", "client_id"),
          CONSTRAINT "oauth2_credentials_pkey" PRIMARY KEY ("id"),
          CONSTRAINT "oauth2_credentials_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT "oauth2_credentials_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_credentials_consumer_id_idx" ON "OAUTH2_CREDENTIALS"("consumer_id" ASC);';


          execute immediate 'CREATE TABLE  IF NOT EXISTS "OAUTH2_AUTHORIZATION_CODES" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "credential_id" varchar2(50),
            "service_id" varchar2(50),
            "code" varchar2(5000),
            "authenticated_userid" text,
            "scope" text,
            "ttl" timestamp(6),
            "challenge" text,
            "challenge_method" text,
            "ws_id" varchar2(50),
            "plugin_id" varchar2(50),
          CONSTRAINT "oauth2_authorization_codes_id_ws_id_unique" UNIQUE ("id", "ws_id"),
          CONSTRAINT "oauth2_authorization_codes_ws_id_code_unique" UNIQUE ("ws_id", "code"),
          CONSTRAINT "oauth2_authorization_codes_pkey" PRIMARY KEY ("id"),
          CONSTRAINT "oauth2_authorization_codes_credential_id_fkey" FOREIGN KEY ("credential_id", "ws_id") REFERENCES "OAUTH2_CREDENTIALS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT "oauth2_authorization_codes_plugin_id_fkey" FOREIGN KEY ("plugin_id") REFERENCES "PLUGINS" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT "oauth2_authorization_codes_service_id_fkey" FOREIGN KEY ("service_id", "ws_id") REFERENCES "SERVICES" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT "oauth2_authorization_codes_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_authorization_codes_ttl_idx" ON "OAUTH2_AUTHORIZATION_CODES"("ttl" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_authorization_credential_id_idx" ON "OAUTH2_AUTHORIZATION_CODES"("credential_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_authorization_service_id_idx" ON "OAUTH2_AUTHORIZATION_CODES"("service_id" ASC);';

          execute immediate 'CREATE TRIGGER oauth2_authorization_codes_ttl_trigger
          AFTER INSERT ON "OAUTH2_AUTHORIZATION_CODES"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from OAUTH2_AUTHORIZATION_CODES where rowid in (select rowid from  OAUTH2_AUTHORIZATION_CODES where "ttl" < CURRENT_TIMESTAMP)'';
          END;';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "OAUTH2_TOKENS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "credential_id" varchar2(50),
            "service_id" varchar2(50),
            "access_token" varchar2(5000),
            "refresh_token" varchar2(5000),
            "token_type" text,
            "expires_in" integer,
            "authenticated_userid" text,
            "scope" text,
            "ttl" timestamp(6),
            "ws_id" varchar2(50),
            CONSTRAINT "oauth2_tokens_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "oauth2_tokens_ws_id_access_token_unique" UNIQUE ("ws_id", "access_token"),
            CONSTRAINT "oauth2_tokens_ws_id_refresh_token_unique" UNIQUE ("ws_id", "refresh_token"),
            CONSTRAINT "oauth2_tokens_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "oauth2_tokens_credential_id_fkey" FOREIGN KEY ("credential_id", "ws_id") REFERENCES "OAUTH2_CREDENTIALS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "oauth2_tokens_service_id_fkey" FOREIGN KEY ("service_id", "ws_id") REFERENCES "SERVICES" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "oauth2_tokens_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_tokens_credential_id_idx" ON "OAUTH2_TOKENS"("credential_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_tokens_service_id_idx" ON "OAUTH2_TOKENS"("service_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "oauth2_tokens_ttl_idx" ON "OAUTH2_TOKENS"("ttl" ASC);';

          execute immediate 'CREATE TRIGGER oauth2_tokens_ttl_trigger
          AFTER INSERT ON "OAUTH2_TOKENS"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from OAUTH2_TOKENS where rowid in (select rowid from  OAUTH2_TOKENS where "ttl" < CURRENT_TIMESTAMP)'';
          END;';
    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "oauth2_credentials" (
        "id"             UUID                         PRIMARY KEY,
        "created_at"     TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"           TEXT,
        "consumer_id"    UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "client_id"      TEXT                         UNIQUE,
        "client_secret"  TEXT,
        "redirect_uris"  TEXT[]
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_consumer_id_idx" ON "oauth2_credentials" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_credentials_secret_idx" ON "oauth2_credentials" ("client_secret");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_authorization_codes" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "code"                  TEXT                         UNIQUE,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT,
        "ttl"                   TIMESTAMP WITH TIME ZONE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_codes_authenticated_userid_idx" ON "oauth2_authorization_codes" ("authenticated_userid");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_credential_id_idx"
                                ON "oauth2_authorization_codes" ("credential_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_authorization_service_id_idx"
                                ON "oauth2_authorization_codes" ("service_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "oauth2_tokens" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "credential_id"         UUID                         REFERENCES "oauth2_credentials" ("id") ON DELETE CASCADE,
        "service_id"            UUID                         REFERENCES "services" ("id") ON DELETE CASCADE,
        "access_token"          TEXT                         UNIQUE,
        "refresh_token"         TEXT                         UNIQUE,
        "token_type"            TEXT,
        "expires_in"            INTEGER,
        "authenticated_userid"  TEXT,
        "scope"                 TEXT,
        "ttl"                   TIMESTAMP WITH TIME ZONE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_authenticated_userid_idx" ON "oauth2_tokens" ("authenticated_userid");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_credential_id_idx"
                                ON "oauth2_tokens" ("credential_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "oauth2_tokens_service_id_idx"
                                ON "oauth2_tokens" ("service_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `oauth2_credentials` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `name` text,
        `consumer_id` varchar(50) DEFAULT NULL,
        `client_id` varchar(50) DEFAULT NULL,
        `client_secret` varchar(200) DEFAULT NULL,
        `redirect_uris` text,
        `tags` varchar(200) DEFAULT NULL,
        `client_type` text,
        `hash_secret` tinyint(1) DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `oauth2_credentials_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `oauth2_credentials_ws_id_client_id_unique` (`ws_id`,`client_id`),
        KEY `oauth2_credentials_consumer_id_idx` (`consumer_id`),
        KEY `oauth2_credentials_secret_idx` (`client_secret`),
        KEY `oauth2_credentials_tags_idex_tags_idx` (`tags`),
        KEY `oauth2_credentials_consumer_id_fkey` (`consumer_id`,`ws_id`),
        CONSTRAINT `oauth2_credentials_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_credentials_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );

      CREATE TABLE IF NOT EXISTS `oauth2_authorization_codes` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `credential_id` varchar(50) DEFAULT NULL,
        `service_id` varchar(50) DEFAULT NULL,
        `code` varchar(200) DEFAULT NULL,
        `authenticated_userid` varchar(200) DEFAULT NULL,
        `scope` text,
        `ttl` timestamp(6) NULL DEFAULT NULL,
        `challenge` text,
        `challenge_method` text,
        `ws_id` varchar(50) DEFAULT NULL,
        `plugin_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `oauth2_authorization_codes_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `oauth2_authorization_codes_ws_id_code_unique` (`ws_id`,`code`),
        KEY `oauth2_authorization_codes_authenticated_userid_idx` (`authenticated_userid`),
        KEY `oauth2_authorization_codes_ttl_idx` (`ttl`),
        KEY `oauth2_authorization_credential_id_idx` (`credential_id`),
        KEY `oauth2_authorization_service_id_idx` (`service_id`),
        KEY `oauth2_authorization_codes_credential_id_fkey` (`credential_id`,`ws_id`),
        KEY `oauth2_authorization_codes_plugin_id_fkey` (`plugin_id`),
        KEY `oauth2_authorization_codes_service_id_fkey` (`service_id`,`ws_id`),
        CONSTRAINT `oauth2_authorization_codes_credential_id_fkey` FOREIGN KEY (`credential_id`, `ws_id`) REFERENCES `oauth2_credentials` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_authorization_codes_plugin_id_fkey` FOREIGN KEY (`plugin_id`) REFERENCES `plugins` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_authorization_codes_service_id_fkey` FOREIGN KEY (`service_id`, `ws_id`) REFERENCES `services` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_authorization_codes_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );

      CREATE TABLE IF NOT EXISTS `oauth2_tokens` (
        `id` varchar(50) NOT NULL,
        `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
        `credential_id` varchar(50) DEFAULT NULL,
        `service_id` varchar(50) DEFAULT NULL,
        `access_token` varchar(200) DEFAULT NULL,
        `refresh_token` varchar(200) DEFAULT NULL,
        `token_type` text,
        `expires_in` int(11) DEFAULT NULL,
        `authenticated_userid` varchar(200) DEFAULT NULL,
        `scope` text,
        `ttl` timestamp(6) NULL DEFAULT NULL,
        `ws_id` varchar(50) DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `oauth2_tokens_id_ws_id_unique` (`id`,`ws_id`),
        UNIQUE KEY `oauth2_tokens_ws_id_access_token_unique` (`ws_id`,`access_token`),
        UNIQUE KEY `oauth2_tokens_ws_id_refresh_token_unique` (`ws_id`,`refresh_token`),
        KEY `oauth2_tokens_authenticated_userid_idx` (`authenticated_userid`),
        KEY `oauth2_tokens_credential_id_idx` (`credential_id`),
        KEY `oauth2_tokens_service_id_idx` (`service_id`),
        KEY `oauth2_tokens_ttl_idx` (`ttl`),
        KEY `oauth2_tokens_credential_id_fkey` (`credential_id`,`ws_id`),
        KEY `oauth2_tokens_service_id_fkey` (`service_id`,`ws_id`),
        CONSTRAINT `oauth2_tokens_credential_id_fkey` FOREIGN KEY (`credential_id`, `ws_id`) REFERENCES `oauth2_credentials` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_tokens_service_id_fkey` FOREIGN KEY (`service_id`, `ws_id`) REFERENCES `services` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
        CONSTRAINT `oauth2_tokens_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
      );
    ]],
  },
}
