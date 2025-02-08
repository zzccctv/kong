return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "cluster_events" (
        "id"         UUID                       PRIMARY KEY,
        "node_id"    UUID                       NOT NULL,
        "at"         TIMESTAMP WITH TIME ZONE   NOT NULL,
        "nbf"        TIMESTAMP WITH TIME ZONE,
        "expire_at"  TIMESTAMP WITH TIME ZONE   NOT NULL,
        "channel"    TEXT,
        "data"       TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "cluster_events_at_idx" ON "cluster_events" ("at");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "cluster_events_channel_idx" ON "cluster_events" ("channel");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      CREATE OR REPLACE FUNCTION "delete_expired_cluster_events" () RETURNS TRIGGER
      LANGUAGE plpgsql
      AS $$
        BEGIN
          DELETE FROM "cluster_events"
                WHERE "expire_at" <= CURRENT_TIMESTAMP AT TIME ZONE 'UTC';
          RETURN NEW;
        END;
      $$;

      DROP TRIGGER IF EXISTS "delete_expired_cluster_events_trigger" ON "cluster_events";
      CREATE TRIGGER "delete_expired_cluster_events_trigger"
        AFTER INSERT ON "cluster_events"
        FOR EACH STATEMENT
        EXECUTE PROCEDURE delete_expired_cluster_events();



      CREATE TABLE IF NOT EXISTS "services" (
        "id"               UUID                       PRIMARY KEY,
        "created_at"       TIMESTAMP WITH TIME ZONE,
        "updated_at"       TIMESTAMP WITH TIME ZONE,
        "name"             TEXT                       UNIQUE,
        "retries"          BIGINT,
        "protocol"         TEXT,
        "host"             TEXT,
        "port"             BIGINT,
        "path"             TEXT,
        "connect_timeout"  BIGINT,
        "write_timeout"    BIGINT,
        "read_timeout"     BIGINT
      );



      CREATE TABLE IF NOT EXISTS "routes" (
        "id"              UUID                       PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE,
        "updated_at"      TIMESTAMP WITH TIME ZONE,
        "name"            TEXT                       UNIQUE,
        "service_id"      UUID                       REFERENCES "services" ("id"),
        "protocols"       TEXT[],
        "methods"         TEXT[],
        "hosts"           TEXT[],
        "paths"           TEXT[],
        "snis"            TEXT[],
        "sources"         JSONB[],
        "destinations"    JSONB[],
        "regex_priority"  BIGINT,
        "strip_path"      BOOLEAN,
        "preserve_host"   BOOLEAN
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "routes_service_id_idx" ON "routes" ("service_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "certificates" (
        "id"          UUID                       PRIMARY KEY,
        "created_at"  TIMESTAMP WITH TIME ZONE   DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "cert"        TEXT,
        "key"         TEXT
      );



      CREATE TABLE IF NOT EXISTS "snis" (
        "id"              UUID                       PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE   DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"            TEXT                       NOT NULL UNIQUE,
        "certificate_id"  UUID                       REFERENCES "certificates" ("id")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "snis_certificate_id_idx" ON "snis" ("certificate_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "consumers" (
        "id"          UUID                         PRIMARY KEY,
        "created_at"  TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "username"    TEXT                         UNIQUE,
        "custom_id"   TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "consumers_username_idx" ON "consumers" (LOWER("username"));
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "plugins" (
        "id"           UUID                         UNIQUE,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"         TEXT                         NOT NULL,
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "service_id"   UUID                         REFERENCES "services"  ("id") ON DELETE CASCADE,
        "route_id"     UUID                         REFERENCES "routes"    ("id") ON DELETE CASCADE,
        "config"       JSONB                        NOT NULL,
        "enabled"      BOOLEAN                      NOT NULL,
        "cache_key"    TEXT                         UNIQUE,
        "run_on"       TEXT,

        PRIMARY KEY ("id")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_name_idx" ON "plugins" ("name");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_consumer_id_idx" ON "plugins" ("consumer_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_service_id_idx" ON "plugins" ("service_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_route_id_idx" ON "plugins" ("route_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_run_on_idx" ON "plugins" ("run_on");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "upstreams" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'),
        "name"                  TEXT                         UNIQUE,
        "hash_on"               TEXT,
        "hash_fallback"         TEXT,
        "hash_on_header"        TEXT,
        "hash_fallback_header"  TEXT,
        "hash_on_cookie"        TEXT,
        "hash_on_cookie_path"   TEXT,
        "slots"                 INTEGER                      NOT NULL,
        "healthchecks"          JSONB
      );



      CREATE TABLE IF NOT EXISTS "targets" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'),
        "upstream_id"  UUID                         REFERENCES "upstreams" ("id") ON DELETE CASCADE,
        "target"       TEXT                         NOT NULL,
        "weight"       INTEGER                      NOT NULL
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "targets_target_idx" ON "targets" ("target");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "targets_upstream_id_idx" ON "targets" ("upstream_id");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "cluster_ca" (
        "pk"    BOOLEAN  NOT NULL  PRIMARY KEY CHECK(pk=true),
        "key"   TEXT     NOT NULL,
        "cert"  TEXT     NOT NULL
      );


      -- TODO: delete on 1.0.0 migrations
      CREATE TABLE IF NOT EXISTS "ttls" (
        "primary_key_value"  TEXT                         NOT NULL,
        "primary_uuid_value" UUID,
        "table_name"         TEXT                         NOT NULL,
        "primary_key_name"   TEXT                         NOT NULL,
        "expire_at"          TIMESTAMP WITHOUT TIME ZONE  NOT NULL,

        PRIMARY KEY ("primary_key_value", "table_name")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "ttls_primary_uuid_value_idx" ON "ttls" ("primary_uuid_value");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;

      CREATE OR REPLACE FUNCTION "upsert_ttl" (v_primary_key_value TEXT, v_primary_uuid_value UUID, v_primary_key_name TEXT, v_table_name TEXT, v_expire_at TIMESTAMP WITHOUT TIME ZONE) RETURNS void
      LANGUAGE plpgsql
      AS $$
        BEGIN
          LOOP
            UPDATE ttls
               SET expire_at = v_expire_at
             WHERE primary_key_value = v_primary_key_value
               AND table_name = v_table_name;

            IF FOUND then
              RETURN;
            END IF;

            BEGIN
              INSERT INTO ttls (primary_key_value, primary_uuid_value, primary_key_name, table_name, expire_at)
                   VALUES (v_primary_key_value, v_primary_uuid_value, v_primary_key_name, v_table_name, v_expire_at);
              RETURN;
            EXCEPTION WHEN unique_violation THEN

            END;
          END LOOP;
        END;
        $$;
    ]]
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS cluster_events(
        channel text,
        at      timestamp,
        node_id uuid,
        id      uuid,
        data    text,
        nbf     timestamp,
        PRIMARY KEY (channel, at, node_id, id)
      ) WITH default_time_to_live = 86400;



      CREATE TABLE IF NOT EXISTS services(
        partition       text,
        id              uuid,
        created_at      timestamp,
        updated_at      timestamp,
        name            text,
        host            text,
        path            text,
        port            int,
        protocol        text,
        connect_timeout int,
        read_timeout    int,
        write_timeout   int,
        retries         int,
        PRIMARY KEY     (partition, id)
      );
      CREATE INDEX IF NOT EXISTS services_name_idx ON services(name);



      CREATE TABLE IF NOT EXISTS routes(
        partition      text,
        id             uuid,
        created_at     timestamp,
        updated_at     timestamp,
        name           text,
        hosts          list<text>,
        paths          list<text>,
        methods        set<text>,
        protocols      set<text>,
        snis           set<text>,
        sources        set<text>,
        destinations   set<text>,
        preserve_host  boolean,
        strip_path     boolean,
        service_id     uuid,
        regex_priority int,
        PRIMARY KEY    (partition, id)
      );
      CREATE INDEX IF NOT EXISTS routes_service_id_idx ON routes(service_id);
      CREATE INDEX IF NOT EXISTS routes_name_idx ON routes(name);



      CREATE TABLE IF NOT EXISTS snis(
        partition          text,
        id                 uuid,
        name               text,
        certificate_id     uuid,
        created_at         timestamp,
        PRIMARY KEY        (partition, id)
      );
      CREATE INDEX IF NOT EXISTS snis_name_idx ON snis(name);
      CREATE INDEX IF NOT EXISTS snis_certificate_id_idx
        ON snis(certificate_id);



      CREATE TABLE IF NOT EXISTS certificates(
        partition text,
        id uuid,
        cert text,
        key text,
        created_at timestamp,
        PRIMARY KEY (partition, id)
      );



      CREATE TABLE IF NOT EXISTS consumers(
        id uuid    PRIMARY KEY,
        created_at timestamp,
        username   text,
        custom_id  text
      );
      CREATE INDEX IF NOT EXISTS consumers_username_idx ON consumers(username);
      CREATE INDEX IF NOT EXISTS consumers_custom_id_idx ON consumers(custom_id);



      CREATE TABLE IF NOT EXISTS plugins(
        id          uuid,
        created_at  timestamp,
        route_id    uuid,
        service_id  uuid,
        consumer_id uuid,
        name        text,
        config      text,
        enabled     boolean,
        cache_key   text,
        run_on      text,
        PRIMARY KEY (id)
      );
      CREATE INDEX IF NOT EXISTS plugins_name_idx ON plugins(name);
      CREATE INDEX IF NOT EXISTS plugins_route_id_idx ON plugins(route_id);
      CREATE INDEX IF NOT EXISTS plugins_service_id_idx ON plugins(service_id);
      CREATE INDEX IF NOT EXISTS plugins_consumer_id_idx ON plugins(consumer_id);
      CREATE INDEX IF NOT EXISTS plugins_cache_key_idx ON plugins(cache_key);
      CREATE INDEX IF NOT EXISTS plugins_run_on_idx ON plugins(run_on);


      CREATE TABLE IF NOT EXISTS upstreams(
        id                   uuid PRIMARY KEY,
        created_at           timestamp,
        hash_fallback        text,
        hash_fallback_header text,
        hash_on              text,
        hash_on_cookie       text,
        hash_on_cookie_path  text,
        hash_on_header       text,
        healthchecks         text,
        name                 text,
        slots                int
      );
      CREATE INDEX IF NOT EXISTS upstreams_name_idx ON upstreams(name);



      CREATE TABLE IF NOT EXISTS targets(
        id          uuid PRIMARY KEY,
        created_at  timestamp,
        target      text,
        upstream_id uuid,
        weight      int
      );
      CREATE INDEX IF NOT EXISTS targets_upstream_id_idx ON targets(upstream_id);
      CREATE INDEX IF NOT EXISTS targets_target_idx ON targets(target);


      CREATE TABLE IF NOT EXISTS cluster_ca(
        pk boolean PRIMARY KEY,
        key text,
        cert text
      );
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "CLUSTER_EVENTS" (
            "id" varchar2(50) NOT NULL,
            "node_id" varchar2(50) NOT NULL,
            "at" timestamp(6) NOT NULL,
            "nbf" timestamp(6),
            "expire_at" timestamp(6) NOT NULL,
            "channel" text,
            "data" text,
             CONSTRAINT "cluster_events_pkey" PRIMARY KEY ("id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "cluster_events_at_idx" ON "CLUSTER_EVENTS"("at" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "cluster_events_expire_at_idx" ON "CLUSTER_EVENTS"("expire_at" ASC);';

          execute immediate 'CREATE TRIGGER cluster_events_ttl_trigger
          AFTER INSERT ON "CLUSTER_EVENTS"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from CLUSTER_EVENTS where rowid in (select rowid from  CLUSTER_EVENTS where "expire_at" < CURRENT_TIMESTAMP)'';
          END;';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "WORKSPACES" (
            "id" varchar2(50) NOT NULL,
            "name" varchar2(500),
            "comment" text,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "meta" text,
            "config" text,
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "workspaces_name_key" UNIQUE ("name"),
            CONSTRAINT "workspaces_pkey" PRIMARY KEY ("id")
          );';

          execute immediate 'INSERT INTO "WORKSPACES"("id", "name") VALUES (newid(), ''default'');';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "CERTIFICATES" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "cert" text,
            "key" text,
            "tags" text,
            "ws_id" varchar2(50),
            "cert_alt" text,
            "key_alt" text,
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
             CONSTRAINT "certificates_id_ws_id_unique" UNIQUE ("id", "ws_id"),
             CONSTRAINT "certificates_pkey" PRIMARY KEY ("id"),
             CONSTRAINT "certificates_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "SERVICES" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6),
            "updated_at" timestamp(6),
            "name" varchar2(500),
            "retries" integer,
            "protocol" text,
            "host" text,
            "port" integer,
            "path" text,
            "connect_timeout" integer,
            "write_timeout" integer,
            "read_timeout" integer,
            "tags" text,
            "client_certificate_id" varchar2(50),
            "tls_verify" number(1,0),
            "tls_verify_depth" integer,
            "ca_certificates" varchar2(50),
            "ws_id" varchar2(50),
            "enabled" number(1,0) DEFAULT 1,
            CONSTRAINT "services_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "services_ws_id_name_unique" UNIQUE ("ws_id", "name"),
            CONSTRAINT "services_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "services_client_certificate_id_fkey" FOREIGN KEY ("client_certificate_id", "ws_id") REFERENCES "CERTIFICATES" ("id", "ws_id") ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT "services_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "services_fkey_client_certificate" ON "SERVICES"("client_certificate_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "ROUTES" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6),
            "updated_at" timestamp(6),
            "name" varchar2(500),
            "service_id" varchar2(50),
            "protocols" text,
            "methods" text,
            "hosts" text,
            "paths" text,
            "snis" text,
            "sources" text,
            "destinations" text,
            "regex_priority" integer,
            "strip_path" number(1,0),
            "preserve_host" number(1,0),
            "tags" text,
            "https_redirect_status_code" integer,
            "headers" text,
            "path_handling" text DEFAULT ''v0'',
            "ws_id" varchar2(50),
            "request_buffering" number(1,0),
            "response_buffering" number(1,0),
            "expression" text,
            "priority" integer,
            CONSTRAINT "routes_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "routes_ws_id_name_unique" UNIQUE ("ws_id", "name"),
            CONSTRAINT "routes_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "routes_service_id_fkey" FOREIGN KEY ("service_id", "ws_id") REFERENCES "SERVICES" ("id", "ws_id") ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT "routes_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "routes_service_id_idx" ON "ROUTES"("service_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "CA_CERTIFICATES" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "cert" text NOT NULL,
            "tags" text,
            "cert_digest" varchar2(5000) NOT NULL,
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "ca_certificates_cert_digest_key" UNIQUE ("cert_digest"),
            CONSTRAINT "ca_certificates_pkey" PRIMARY KEY ("id")
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "CLUSTERING_DATA_PLANES" (
            "id" varchar2(50) NOT NULL,
            "hostname" text NOT NULL,
            "ip" text NOT NULL,
            "last_seen" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "config_hash" text NOT NULL,
            "ttl" timestamp(6),
            "version" text ,
            "sync_status" text DEFAULT ''unknown'',
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "clustering_data_planes_pkey" PRIMARY KEY ("id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "clustering_data_planes_ttl_idx" ON "CLUSTERING_DATA_PLANES"("ttl" ASC);';

          execute immediate 'CREATE TRIGGER clustering_data_planes_ttl_trigger
          AFTER INSERT ON "CLUSTERING_DATA_PLANES"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from CLUSTERING_DATA_PLANES where rowid in (select rowid from  CLUSTERING_DATA_PLANES where "ttl" < CURRENT_TIMESTAMP)'';
          END;';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "CONSUMERS" (
            "id"  varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "username" varchar2(500),
            "custom_id" varchar2(50),
            "tags" text,
            "ws_id" varchar2(50),
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "consumers_ws_id_username_unique" UNIQUE ("ws_id", "username"),
            CONSTRAINT "consumers_ws_id_custom_id_unique" UNIQUE ("ws_id", "custom_id"),
            CONSTRAINT "consumers_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "consumers_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "consumers_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "KEY_SETS" (
            "id"  varchar2(50) NOT NULL,
            "name" varchar2(500),
            "tags" text,
            "ws_id"  varchar2(50),
            "created_at" timestamp(6),
            "updated_at" timestamp(6),
            CONSTRAINT "key_sets_name_key" UNIQUE ("name"),
            CONSTRAINT "key_sets_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "key_sets_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "KEYS" (
            "id" varchar2(50) NOT NULL,
            "set_id" varchar2(50),
            "name" varchar2(500),
            "cache_key" varchar2(500),
            "ws_id" varchar2(50),
            "kid" varchar2(5000),
            "jwk" text,
            "pem" text,
            "tags" text,
            "created_at" timestamp(6),
            "updated_at" timestamp(6),
            CONSTRAINT "keys_name_key" UNIQUE ("name"),
            CONSTRAINT "keys_cache_key_key" UNIQUE ("cache_key"),
            CONSTRAINT "keys_kid_set_id_key" UNIQUE ("kid", "set_id"),
            CONSTRAINT "keys_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "keys_set_id_fkey" FOREIGN KEY ("set_id") REFERENCES "KEY_SETS" ("id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "keys_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "keys_fkey_key_sets" ON "KEYS"("set_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "PARAMETERS" (
            "key" varchar2(5000) NOT NULL,
            "value" text NOT NULL,
            "created_at" timestamp(6),
            CONSTRAINT "parameters_pkey" PRIMARY KEY ("key")
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "PLUGINS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "name" text NOT NULL,
            "consumer_id" varchar2(50),
            "service_id" varchar2(50),
            "route_id" varchar2(50),
            "config" text NOT NULL,
            "enabled" number(1,0) NOT NULL,
            "cache_key" varchar2(500),
            "protocols" text,
            "tags" text,
            "ws_id" varchar2(50),
            "instance_name" varchar2(5000),
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "plugins_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "plugins_cache_key_key" UNIQUE ("cache_key"),
            CONSTRAINT "plugins_ws_id_instance_name_unique" UNIQUE ("ws_id", "instance_name"),
            CONSTRAINT "plugins_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "plugins_consumer_id_fkey" FOREIGN KEY ("consumer_id", "ws_id") REFERENCES "CONSUMERS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "plugins_route_id_fkey" FOREIGN KEY ("route_id", "ws_id") REFERENCES "ROUTES" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "plugins_service_id_fkey" FOREIGN KEY ("service_id", "ws_id") REFERENCES "SERVICES" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
            CONSTRAINT "plugins_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "plugins_consumer_id_idx" ON "PLUGINS"("consumer_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "plugins_route_id_idx" ON "PLUGINS"("route_id" ASC);';
          execute immediate 'CREATE INDEX IF NOT EXISTS "plugins_service_id_idx" ON "PLUGINS"("service_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "SCHEMA_META" (
            "key" varchar2(500) NOT NULL,
            "subsystem" varchar2(500) NOT NULL,
            "last_executed" text,
            "executed" text,
            "pending" text,
            CONSTRAINT "schema_meta_pkey" PRIMARY KEY ("key", "subsystem")
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "SM_VAULTS" (
            "id" varchar2(50) NOT NULL,
            "ws_id" varchar2(50),
            "prefix" varchar2(5000),
            "name" text NOT NULL,
            "description" text,
            "config" text NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            "updated_at" timestamp(6),
            "tags" text,
            CONSTRAINT "sm_vaults_prefix_key" UNIQUE ("prefix"),
            CONSTRAINT "sm_vaults_id_ws_id_key" UNIQUE ("id", "ws_id"),
            CONSTRAINT "sm_vaults_prefix_ws_id_key" UNIQUE ("prefix", "ws_id"),
            CONSTRAINT "sm_vaults_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "sm_vaults_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "SNIS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT  CURRENT_TIMESTAMP(0),
            "name" varchar2(500) NOT NULL,
            "certificate_id" varchar2(50),
            "tags" text,
            "ws_id" varchar2(50),
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "snis_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "snis_name_key" UNIQUE ("name"),
            CONSTRAINT "snis_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "snis_certificate_id_fkey" FOREIGN KEY ("certificate_id", "ws_id") REFERENCES "CERTIFICATES" ("id", "ws_id") ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT "snis_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "snis_certificate_id_idx" ON "SNIS"("certificate_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "TAGS" (
            "entity_id" varchar2(50) NOT NULL,
            "entity_name" varchar2(5000),
            "tags" text,
            CONSTRAINT "tags_pkey" PRIMARY KEY ("entity_id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "tags_entity_name_idx" ON "TAGS"("entity_name" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "UPSTREAMS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(3),
            "name" varchar2(500),
            "hash_on" text,
            "hash_fallback" text,
            "hash_on_header" text,
            "hash_fallback_header" text,
            "hash_on_cookie" text,
            "hash_on_cookie_path" text,
            "slots" integer NOT NULL,
            "healthchecks" text,
            "tags" text,
            "algorithm" text,
            "host_header" text,
            "client_certificate_id" varchar2(50),
            "ws_id" varchar2(50),
            "hash_on_query_arg" text,
            "hash_fallback_query_arg" text,
            "hash_on_uri_capture" text,
            "hash_fallback_uri_capture" text,
            "use_srv_name" number(1,0) DEFAULT 1,
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(0),
            CONSTRAINT "upstreams_id_ws_id_unique" UNIQUE ("id", "ws_id"),
            CONSTRAINT "upstreams_ws_id_name_unique" UNIQUE ("ws_id", "name"),
            CONSTRAINT "upstreams_pkey" PRIMARY KEY ("id"),
            CONSTRAINT "upstreams_client_certificate_id_fkey" FOREIGN KEY ("client_certificate_id") REFERENCES "CERTIFICATES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION,
            CONSTRAINT "upstreams_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "upstreams_fkey_client_certificate" ON "UPSTREAMS"("client_certificate_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "TARGETS" (
            "id" varchar2(50) NOT NULL,
            "created_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(3),
            "upstream_id" varchar2(50),
            "target" text NOT NULL,
            "weight" integer NOT NULL,
            "tags" text,
            "ws_id" varchar2(50),
            "cache_key" varchar2(500),
            "updated_at" timestamp(6) DEFAULT CURRENT_TIMESTAMP(3),
             CONSTRAINT "targets_id_ws_id_unique" UNIQUE ("id", "ws_id"),
             CONSTRAINT "targets_cache_key_key" UNIQUE ("cache_key"),
             CONSTRAINT "targets_pkey" PRIMARY KEY ("id"),
             CONSTRAINT "targets_upstream_id_fkey" FOREIGN KEY ("upstream_id", "ws_id") REFERENCES "UPSTREAMS" ("id", "ws_id") ON DELETE CASCADE ON UPDATE NO ACTION,
             CONSTRAINT "targets_ws_id_fkey" FOREIGN KEY ("ws_id") REFERENCES "WORKSPACES" ("id") ON DELETE NO ACTION ON UPDATE NO ACTION
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "targets_upstream_id_idx" ON "TARGETS"("upstream_id" ASC);';

          execute immediate 'CREATE TABLE  IF NOT EXISTS "TTLS" (
            "primary_key_value" varchar2(5000) NOT NULL,
            "primary_uuid_value" varchar2(50),
            "table_name" varchar2(5000) NOT NULL,
            "primary_key_name" text NOT NULL,
            "expire_at" timestamp(6) NOT NULL,
            CONSTRAINT "ttls_pkey" PRIMARY KEY ("primary_key_value", "table_name")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "ttls_primary_uuid_value_idx" ON "TTLS"("primary_uuid_value" ASC);';
    ]],
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "cluster_events" (
        "id"         UUID                       PRIMARY KEY,
        "node_id"    UUID                       NOT NULL,
        "at"         TIMESTAMP WITH TIME ZONE   NOT NULL,
        "nbf"        TIMESTAMP WITH TIME ZONE,
        "expire_at"  TIMESTAMP WITH TIME ZONE   NOT NULL,
        "channel"    TEXT,
        "data"       TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "cluster_events_at_idx" ON "cluster_events" ("at");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "cluster_events_channel_idx" ON "cluster_events" ("channel");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      CREATE OR REPLACE FUNCTION "delete_expired_cluster_events" () RETURNS TRIGGER
      LANGUAGE plpgsql
      AS $$
        BEGIN
          DELETE FROM "cluster_events"
                WHERE "expire_at" <= CURRENT_TIMESTAMP AT TIME ZONE 'UTC';
          RETURN NEW;
        END;
      $$;

      DROP TRIGGER IF EXISTS "delete_expired_cluster_events_trigger" ON "cluster_events";
      CREATE TRIGGER "delete_expired_cluster_events_trigger"
        AFTER INSERT ON "cluster_events"
        FOR EACH STATEMENT
        EXECUTE PROCEDURE delete_expired_cluster_events();



      CREATE TABLE IF NOT EXISTS "services" (
        "id"               UUID                       PRIMARY KEY,
        "created_at"       TIMESTAMP WITH TIME ZONE,
        "updated_at"       TIMESTAMP WITH TIME ZONE,
        "name"             TEXT                       UNIQUE,
        "retries"          BIGINT,
        "protocol"         TEXT,
        "host"             TEXT,
        "port"             BIGINT,
        "path"             TEXT,
        "connect_timeout"  BIGINT,
        "write_timeout"    BIGINT,
        "read_timeout"     BIGINT
      );



      CREATE TABLE IF NOT EXISTS "routes" (
        "id"              UUID                       PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE,
        "updated_at"      TIMESTAMP WITH TIME ZONE,
        "name"            TEXT                       UNIQUE,
        "service_id"      UUID                       REFERENCES "services" ("id"),
        "protocols"       TEXT[],
        "methods"         TEXT[],
        "hosts"           TEXT[],
        "paths"           TEXT[],
        "snis"            TEXT[],
        "sources"         JSONB[],
        "destinations"    JSONB[],
        "regex_priority"  BIGINT,
        "strip_path"      BOOLEAN,
        "preserve_host"   BOOLEAN
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "routes_service_id_idx" ON "routes" ("service_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "certificates" (
        "id"          UUID                       PRIMARY KEY,
        "created_at"  TIMESTAMP WITH TIME ZONE   DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "cert"        TEXT,
        "key"         TEXT
      );



      CREATE TABLE IF NOT EXISTS "snis" (
        "id"              UUID                       PRIMARY KEY,
        "created_at"      TIMESTAMP WITH TIME ZONE   DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"            TEXT                       NOT NULL UNIQUE,
        "certificate_id"  UUID                       REFERENCES "certificates" ("id")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "snis_certificate_id_idx" ON "snis" ("certificate_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "consumers" (
        "id"          UUID                         PRIMARY KEY,
        "created_at"  TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "username"    TEXT                         UNIQUE,
        "custom_id"   TEXT                         UNIQUE
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "consumers_username_idx" ON "consumers" (LOWER("username"));
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "plugins" (
        "id"           UUID                         UNIQUE,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(0) AT TIME ZONE 'UTC'),
        "name"         TEXT                         NOT NULL,
        "consumer_id"  UUID                         REFERENCES "consumers" ("id") ON DELETE CASCADE,
        "service_id"   UUID                         REFERENCES "services"  ("id") ON DELETE CASCADE,
        "route_id"     UUID                         REFERENCES "routes"    ("id") ON DELETE CASCADE,
        "config"       JSONB                        NOT NULL,
        "enabled"      BOOLEAN                      NOT NULL,
        "cache_key"    TEXT                         UNIQUE,
        "run_on"       TEXT,

        PRIMARY KEY ("id")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_name_idx" ON "plugins" ("name");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_consumer_id_idx" ON "plugins" ("consumer_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_service_id_idx" ON "plugins" ("service_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_route_id_idx" ON "plugins" ("route_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "plugins_run_on_idx" ON "plugins" ("run_on");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "upstreams" (
        "id"                    UUID                         PRIMARY KEY,
        "created_at"            TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'),
        "name"                  TEXT                         UNIQUE,
        "hash_on"               TEXT,
        "hash_fallback"         TEXT,
        "hash_on_header"        TEXT,
        "hash_fallback_header"  TEXT,
        "hash_on_cookie"        TEXT,
        "hash_on_cookie_path"   TEXT,
        "slots"                 INTEGER                      NOT NULL,
        "healthchecks"          JSONB
      );



      CREATE TABLE IF NOT EXISTS "targets" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITH TIME ZONE     DEFAULT (CURRENT_TIMESTAMP(3) AT TIME ZONE 'UTC'),
        "upstream_id"  UUID                         REFERENCES "upstreams" ("id") ON DELETE CASCADE,
        "target"       TEXT                         NOT NULL,
        "weight"       INTEGER                      NOT NULL
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "targets_target_idx" ON "targets" ("target");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "targets_upstream_id_idx" ON "targets" ("upstream_id");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;



      CREATE TABLE IF NOT EXISTS "cluster_ca" (
        "pk"    BOOLEAN  NOT NULL  PRIMARY KEY CHECK(pk=true),
        "key"   TEXT     NOT NULL,
        "cert"  TEXT     NOT NULL
      );


      -- TODO: delete on 1.0.0 migrations
      CREATE TABLE IF NOT EXISTS "ttls" (
        "primary_key_value"  TEXT                         NOT NULL,
        "primary_uuid_value" UUID,
        "table_name"         TEXT                         NOT NULL,
        "primary_key_name"   TEXT                         NOT NULL,
        "expire_at"          TIMESTAMP WITHOUT TIME ZONE  NOT NULL,

        PRIMARY KEY ("primary_key_value", "table_name")
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "ttls_primary_uuid_value_idx" ON "ttls" ("primary_uuid_value");
      EXCEPTION WHEN undefined_column THEN
        -- Do nothing, accept existing state
      END$$;

      CREATE OR REPLACE FUNCTION "upsert_ttl" (v_primary_key_value TEXT, v_primary_uuid_value UUID, v_primary_key_name TEXT, v_table_name TEXT, v_expire_at TIMESTAMP WITHOUT TIME ZONE) RETURNS void
      LANGUAGE plpgsql
      AS $$
        BEGIN
          LOOP
            UPDATE ttls
               SET expire_at = v_expire_at
             WHERE primary_key_value = v_primary_key_value
               AND table_name = v_table_name;

            IF FOUND then
              RETURN;
            END IF;

            BEGIN
              INSERT INTO ttls (primary_key_value, primary_uuid_value, primary_key_name, table_name, expire_at)
                   VALUES (v_primary_key_value, v_primary_uuid_value, v_primary_key_name, v_table_name, v_expire_at);
              RETURN;
            EXCEPTION WHEN unique_violation THEN

            END;
          END LOOP;
        END;
        $$;
    ]]
  },

  mysql = {
    up = [[
        CREATE TABLE IF NOT EXISTS `cluster_events` (
          `id` varchar(50) NOT NULL,
          `node_id` varchar(50) NOT NULL,
          `at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
          `nbf` timestamp(6) NULL DEFAULT NULL,
          `expire_at` timestamp(6) NULL DEFAULT NULL,
          `channel` varchar(200) DEFAULT NULL,
          `data` text,
          PRIMARY KEY (`id`),
          KEY `cluster_events_at_idx` (`at`),
          KEY `cluster_events_channel_idx` (`channel`),
          KEY `cluster_events_expire_at_idx` (`expire_at`)
        );

        CREATE TABLE IF NOT EXISTS `workspaces` (
          `id` varchar(50) NOT NULL,
          `name` varchar(200) DEFAULT NULL,
          `comment` text,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `meta` text,
          `config` text,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `workspaces_name_key` (`name`)
        );
        INSERT INTO workspaces(`id`, `name`) VALUES (UUID(), "default");

        CREATE TABLE IF NOT EXISTS `certificates` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `cert` text,
          `key` text,
          `tags` text,
          `ws_id` varchar(50) DEFAULT NULL,
          `cert_alt` text,
          `key_alt` text,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `certificates_id_ws_id_unique` (`id`,`ws_id`),
          KEY `certificates_ws_id_fkey` (`ws_id`),
          CONSTRAINT `certificates_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `services` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NULL DEFAULT NULL,
          `updated_at` timestamp(6) NULL DEFAULT NULL,
          `name` varchar(200) DEFAULT NULL,
          `retries` bigint(20) DEFAULT NULL,
          `protocol` text,
          `host` text,
          `port` bigint(20) DEFAULT NULL,
          `path` text,
          `connect_timeout` bigint(20) DEFAULT NULL,
          `write_timeout` bigint(20) DEFAULT NULL,
          `read_timeout` bigint(20) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `client_certificate_id` varchar(50) DEFAULT NULL,
          `tls_verify` tinyint(1) DEFAULT NULL,
          `tls_verify_depth` smallint(6) DEFAULT NULL,
          `ca_certificates` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `enabled` tinyint(1) DEFAULT '1',
          PRIMARY KEY (`id`),
          UNIQUE KEY `services_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `services_ws_id_name_unique` (`ws_id`,`name`),
          KEY `services_fkey_client_certificate` (`client_certificate_id`),
          KEY `services_tags_idx` (`tags`),
          KEY `services_client_certificate_id_fkey` (`client_certificate_id`,`ws_id`),
          CONSTRAINT `services_client_certificate_id_fkey` FOREIGN KEY (`client_certificate_id`, `ws_id`) REFERENCES `certificates` (`id`, `ws_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
          CONSTRAINT `services_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `routes` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NULL DEFAULT NULL,
          `updated_at` timestamp(6) NULL DEFAULT NULL,
          `name` varchar(50) DEFAULT NULL,
          `service_id` varchar(50) DEFAULT NULL,
          `protocols` text,
          `methods` text,
          `hosts` text,
          `paths` text,
          `snis` text,
          `sources` text,
          `destinations` text,
          `regex_priority` bigint(20) DEFAULT NULL,
          `strip_path` tinyint(1) DEFAULT NULL,
          `preserve_host` tinyint(1) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `https_redirect_status_code` int(11) DEFAULT NULL,
          `headers` text,
          `path_handling` varchar(200) DEFAULT 'v0',
          `ws_id` varchar(50) DEFAULT NULL,
          `request_buffering` tinyint(1) DEFAULT NULL,
          `response_buffering` tinyint(1) DEFAULT NULL,
          `expression` text,
          `priority` bigint(20) DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `routes_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `routes_ws_id_name_unique` (`ws_id`,`name`),
          KEY `routes_service_id_idx` (`service_id`),
          KEY `routes_tags_idx` (`tags`),
          KEY `routes_service_id_fkey` (`service_id`,`ws_id`),
          CONSTRAINT `routes_service_id_fkey` FOREIGN KEY (`service_id`, `ws_id`) REFERENCES `services` (`id`, `ws_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
          CONSTRAINT `routes_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `ca_certificates` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `cert` text,
          `tags` varchar(200) DEFAULT NULL,
          `cert_digest` varchar(200) DEFAULT NULL,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `ca_certificates_cert_digest_key` (`cert_digest`),
          KEY `certificates_tags_idx` (`tags`)
        );

        CREATE TABLE IF NOT EXISTS `clustering_data_planes` (
          `id` varchar(50) NOT NULL,
          `hostname` text,
          `ip` text,
          `last_seen` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `config_hash` text,
          `ttl` timestamp(6) NULL DEFAULT NULL,
          `version` text,
          `sync_status` varchar(200) NOT NULL DEFAULT 'unknown',
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          KEY `clustering_data_planes_ttl_idx` (`ttl`)
        );

        CREATE TABLE IF NOT EXISTS `consumers` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `username` varchar(200) DEFAULT NULL,
          `custom_id` varchar(50) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `consumers_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `consumers_ws_id_username_unique` (`ws_id`,`username`),
          UNIQUE KEY `consumers_ws_id_custom_id_unique` (`ws_id`,`custom_id`),
          KEY `consumers_tags_idx` (`tags`),
          KEY `consumers_username_idx` (`username`),
          CONSTRAINT `consumers_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `key_sets` (
          `id` varchar(50) NOT NULL,
          `name` varchar(200) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `created_at` timestamp(6) NULL DEFAULT NULL,
          `updated_at` timestamp(6) NULL DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `key_sets_name_key` (`name`),
          KEY `key_sets_tags_idx` (`tags`),
          KEY `key_sets_ws_id_fkey` (`ws_id`),
          CONSTRAINT `key_sets_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `keys` (
          `id` varchar(50) NOT NULL,
          `set_id` varchar(50) DEFAULT NULL,
          `name` varchar(200) DEFAULT NULL,
          `cache_key` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `kid` varchar(200) DEFAULT NULL,
          `jwk` text,
          `pem` text,
          `tags` varchar(200) DEFAULT NULL,
          `created_at` timestamp(6) NULL DEFAULT NULL,
          `updated_at` timestamp(6) NULL DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `keys_name_key` (`name`),
          UNIQUE KEY `keys_kid_set_id_key` (`kid`,`set_id`),
          KEY `keys_fkey_key_sets` (`set_id`),
          KEY `keys_tags_idx` (`tags`),
          KEY `keys_ws_id_fkey` (`ws_id`),
          CONSTRAINT `keys_set_id_fkey` FOREIGN KEY (`set_id`) REFERENCES `key_sets` (`id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT `keys_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `parameters` (
          `key` varchar(50) NOT NULL,
          `value` text NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6)
        );

        CREATE TABLE IF NOT EXISTS `plugins` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `name` varchar(200) NOT NULL,
          `consumer_id` varchar(50) DEFAULT NULL,
          `service_id` varchar(50) DEFAULT NULL,
          `route_id` varchar(50) DEFAULT NULL,
          `config` text NOT NULL,
          `enabled` tinyint(1) NOT NULL,
          `cache_key` varchar(200) DEFAULT NULL,
          `protocols` text,
          `tags` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `instance_name` varchar(200) DEFAULT NULL,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `plugins_cache_key_key` (`cache_key`),
          UNIQUE KEY `plugins_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `plugins_ws_id_instance_name_unique` (`ws_id`,`instance_name`),
          KEY `plugins_consumer_id_idx` (`consumer_id`),
          KEY `plugins_name_idx` (`name`),
          KEY `plugins_route_id_idx` (`route_id`),
          KEY `plugins_service_id_idx` (`service_id`),
          KEY `plugins_tags_idx` (`tags`),
          KEY `plugins_consumer_id_fkey` (`consumer_id`,`ws_id`),
          KEY `plugins_route_id_fkey` (`route_id`,`ws_id`),
          KEY `plugins_service_id_fkey` (`service_id`,`ws_id`),
          CONSTRAINT `plugins_consumer_id_fkey` FOREIGN KEY (`consumer_id`, `ws_id`) REFERENCES `consumers` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT `plugins_route_id_fkey` FOREIGN KEY (`route_id`, `ws_id`) REFERENCES `routes` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT `plugins_service_id_fkey` FOREIGN KEY (`service_id`, `ws_id`) REFERENCES `services` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT `plugins_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `schema_meta` (
          `key` varchar(50) NOT NULL,
          `subsystem` varchar(200) NOT NULL,
          `last_executed` text,
          `executed` text,
          `pending` text,
          PRIMARY KEY (`key`,`subsystem`)
        );

        CREATE TABLE IF NOT EXISTS `sm_vaults` (
          `id` varchar(50) NOT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `prefix` varchar(200) DEFAULT NULL,
          `name` text NOT NULL,
          `description` text,
          `config` text NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `updated_at` timestamp(6) NULL DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          PRIMARY KEY (`id`),
          UNIQUE KEY `sm_vaults_prefix_key` (`prefix`),
          UNIQUE KEY `sm_vaults_id_ws_id_key` (`id`,`ws_id`),
          UNIQUE KEY `sm_vaults_prefix_ws_id_key` (`prefix`,`ws_id`),
          KEY `sm_vaults_tags_idx` (`tags`),
          KEY `sm_vaults_ws_id_fkey` (`ws_id`),
          CONSTRAINT `sm_vaults_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `snis` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `name` varchar(200) NOT NULL,
          `certificate_id` varchar(50) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `snis_name_key` (`name`),
          UNIQUE KEY `snis_id_ws_id_unique` (`id`,`ws_id`),
          KEY `snis_certificate_id_idx` (`certificate_id`),
          KEY `snis_tags_idx` (`tags`),
          KEY `snis_certificate_id_fkey` (`certificate_id`,`ws_id`),
          KEY `snis_ws_id_fkey` (`ws_id`),
          CONSTRAINT `snis_certificate_id_fkey` FOREIGN KEY (`certificate_id`, `ws_id`) REFERENCES `certificates` (`id`, `ws_id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
          CONSTRAINT `snis_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `tags` (
          `entity_id` varchar(50) NOT NULL,
          `entity_name` varchar(200) DEFAULT NULL,
          `tags` varchar(200) DEFAULT NULL,
          PRIMARY KEY (`entity_id`),
          KEY `tags_entity_name_idx` (`entity_name`),
          KEY `tags_tags_idx` (`tags`)
        );

        CREATE TABLE IF NOT EXISTS `upstreams` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `name` varchar(200) DEFAULT NULL,
          `hash_on` text,
          `hash_fallback` text,
          `hash_on_header` text,
          `hash_fallback_header` text,
          `hash_on_cookie` text,
          `hash_on_cookie_path` text,
          `slots` int(11) NOT NULL,
          `healthchecks` text,
          `tags` varchar(200) DEFAULT NULL,
          `algorithm` text,
          `host_header` text,
          `client_certificate_id` varchar(50) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `hash_on_query_arg` text,
          `hash_fallback_query_arg` text,
          `hash_on_uri_capture` text,
          `hash_fallback_uri_capture` text,
          `use_srv_name` tinyint(1) DEFAULT '0',
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `upstreams_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `upstreams_ws_id_name_unique` (`ws_id`,`name`),
          KEY `upstreams_fkey_client_certificate` (`client_certificate_id`),
          KEY `upstreams_tags_idx` (`tags`),
          CONSTRAINT `upstreams_client_certificate_id_fkey` FOREIGN KEY (`client_certificate_id`) REFERENCES `certificates` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION,
          CONSTRAINT `upstreams_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE IF NOT EXISTS `targets` (
          `id` varchar(50) NOT NULL,
          `created_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          `upstream_id` varchar(50) DEFAULT NULL,
          `target` varchar(200) NOT NULL,
          `weight` int(11) NOT NULL,
          `tags` varchar(200) DEFAULT NULL,
          `ws_id` varchar(50) DEFAULT NULL,
          `cache_key` varchar(200) DEFAULT NULL,
          `updated_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`id`),
          UNIQUE KEY `targets_id_ws_id_unique` (`id`,`ws_id`),
          UNIQUE KEY `targets_cache_key_key` (`cache_key`),
          KEY `targets_tags_idx` (`tags`),
          KEY `targets_target_idx` (`target`),
          KEY `targets_upstream_id_idx` (`upstream_id`),
          KEY `targets_upstream_id_fkey` (`upstream_id`,`ws_id`),
          KEY `targets_ws_id_fkey` (`ws_id`),
          CONSTRAINT `targets_upstream_id_fkey` FOREIGN KEY (`upstream_id`, `ws_id`) REFERENCES `upstreams` (`id`, `ws_id`) ON DELETE CASCADE ON UPDATE NO ACTION,
          CONSTRAINT `targets_ws_id_fkey` FOREIGN KEY (`ws_id`) REFERENCES `workspaces` (`id`) ON DELETE NO ACTION ON UPDATE NO ACTION
        );

        CREATE TABLE `ttls` (
          `primary_key_value` varchar(200) NOT NULL,
          `primary_uuid_value` varchar(200) DEFAULT NULL,
          `table_name` varchar(200) NOT NULL,
          `primary_key_name` text NOT NULL,
          `expire_at` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
          PRIMARY KEY (`primary_key_value`,`table_name`),
          KEY `primary_uuid_value` (`primary_uuid_value`)
        );
    ]]
  },

}
