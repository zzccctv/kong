return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acme_storage" (
        "id"          UUID   PRIMARY KEY,
        "key"         TEXT   UNIQUE,
        "value"       TEXT,
        "created_at"  TIMESTAMP WITH TIME ZONE,
        "ttl"         TIMESTAMP WITH TIME ZONE
      );
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS acme_storage (
        id          uuid PRIMARY KEY,
        key         text,
        value       text,
        created_at  timestamp
      );
      CREATE INDEX IF NOT EXISTS acme_storage_key_idx ON acme_storage(key);
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "ACME_STORAGE" (
            "id" varchar2(50) NOT NULL,
            "key" varchar2(500),
            "value" text,
            "created_at" timestamp(6),
            "ttl" timestamp(6),
            CONSTRAINT "acme_storage_key_key" UNIQUE ("key"),
            CONSTRAINT "acme_storage_pkey" PRIMARY KEY ("id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "acme_storage_ttl_idx" ON "ACME_STORAGE"("ttl" ASC);';

          execute immediate 'CREATE TRIGGER acme_storage_ttl_trigger
          AFTER INSERT ON "ACME_STORAGE"
          FOR EACH STATEMENT
          BEGIN
          EXECUTE IMMEDIATE ''delete from ACME_STORAGE where rowid in (select rowid from  ACME_STORAGE where "ttl" < CURRENT_TIMESTAMP)'';
          END;';

    ]],
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acme_storage" (
        "id"          UUID   PRIMARY KEY,
        "key"         TEXT   UNIQUE,
        "value"       TEXT,
        "created_at"  TIMESTAMP WITH TIME ZONE,
        "ttl"         TIMESTAMP WITH TIME ZONE
      );
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `acme_storage` (
        `id` varchar(50) NOT NULL,
        `key` varchar(200) DEFAULT NULL,
        `value` text,
        `created_at` timestamp(6) NULL DEFAULT NULL,
        `ttl` timestamp(6) NULL DEFAULT NULL,
        PRIMARY KEY (`id`),
        UNIQUE KEY `acme_storage_key_key` (`key`),
        KEY `acme_storage_ttl_idx` (`ttl`) USING BTREE
      );
    ]],
  },
}
