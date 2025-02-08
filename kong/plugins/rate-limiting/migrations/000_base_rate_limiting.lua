return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "ratelimiting_metrics" (
        "identifier"   TEXT                         NOT NULL,
        "period"       TEXT                         NOT NULL,
        "period_date"  TIMESTAMP WITH TIME ZONE     NOT NULL,
        "service_id"   UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID,
        "route_id"     UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID,
        "value"        INTEGER,

        PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
      );
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS ratelimiting_metrics(
        route_id    uuid,
        service_id  uuid,
        period_date timestamp,
        period      text,
        identifier  text,
        value       counter,
        PRIMARY KEY ((route_id, service_id, identifier, period_date, period))
      );
    ]],
  },

  dm = {
    up = [[
          execute immediate 'CREATE TABLE  IF NOT EXISTS "RATELIMITING_METRICS" (
            "identifier" varchar2(5000) NOT NULL,
            "period" varchar2(5000) NOT NULL,
            "period_date" timestamp(6) NOT NULL,
            "service_id" varchar2(50) NOT NULL DEFAULT ''00000000-0000-0000-0000-000000000000'',
            "route_id" varchar2(50) NOT NULL DEFAULT ''00000000-0000-0000-0000-000000000000'',
            "value" integer,
            "ttl" timestamp(6),
            CONSTRAINT "ratelimiting_metrics_pkey" PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "ratelimiting_metrics_idx" ON "RATELIMITING_METRICS"(
          "service_id" ASC,
          "route_id" ASC,
          "period_date" ASC,
          "period" ASC
          );';
          execute immediate 'CREATE INDEX IF NOT EXISTS "ratelimiting_metrics_ttl_idx" ON "RATELIMITING_METRICS" ("ttl" ASC);';

          execute immediate 'CREATE TRIGGER ratelimiting_metrics_ttl_trigger
          AFTER INSERT ON "RATELIMITING_METRICS"
          FOR EACH ROW
          BEGIN
          EXECUTE IMMEDIATE ''delete from RATELIMITING_METRICS where rowid in (select rowid from  RATELIMITING_METRICS where "ttl" < CURRENT_TIMESTAMP)'';
          END;';
    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "ratelimiting_metrics" (
        "identifier"   TEXT                         NOT NULL,
        "period"       TEXT                         NOT NULL,
        "period_date"  TIMESTAMP WITH TIME ZONE     NOT NULL,
        "service_id"   UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID,
        "route_id"     UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::UUID,
        "value"        INTEGER,

        PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
      );
    ]],
  },

  mysql = {
    up = [[
        CREATE TABLE IF NOT EXISTS `ratelimiting_metrics` (
          `identifier` varchar(50) NOT NULL,
          `period` varchar(200) NOT NULL,
          `period_date` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
          `service_id` varchar(50) NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
          `route_id` varchar(50) NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
          `value` int(11) DEFAULT NULL,
          `ttl` timestamp(6) NULL DEFAULT NULL,
          PRIMARY KEY (`identifier`,`period`,`period_date`,`service_id`,`route_id`),
          KEY `ratelimiting_metrics_idx` (`period`,`period_date`,`service_id`,`route_id`),
          KEY `ratelimiting_metrics_ttl_idx` (`ttl`)
        );
    ]],
  },
}
