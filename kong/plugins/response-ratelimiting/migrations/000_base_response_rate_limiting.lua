return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "response_ratelimiting_metrics" (
        "identifier"   TEXT                         NOT NULL,
        "period"       TEXT                         NOT NULL,
        "period_date"  TIMESTAMP WITH TIME ZONE     NOT NULL,
        "service_id"   UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
        "route_id"     UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
        "value"        INTEGER,

        PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
      );
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS response_ratelimiting_metrics(
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
           execute immediate 'CREATE TABLE  IF NOT EXISTS "RESPONSE_RATELIMITING_METRICS" (
            "identifier" varchar2(5000) NOT NULL,
            "period" varchar2(5000) NOT NULL,
            "period_date" timestamp(6) NOT NULL,
            "service_id" varchar2(50) NOT NULL DEFAULT ''00000000-0000-0000-0000-000000000000'',
            "route_id" varchar2(50) NOT NULL DEFAULT ''00000000-0000-0000-0000-000000000000'',
            "value" integer,
            CONSTRAINT "response_ratelimiting_metrics_pkey" PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
          );';

    ]]
  },

  highgo = {
    up = [[
      CREATE TABLE IF NOT EXISTS "response_ratelimiting_metrics" (
        "identifier"   TEXT                         NOT NULL,
        "period"       TEXT                         NOT NULL,
        "period_date"  TIMESTAMP WITH TIME ZONE     NOT NULL,
        "service_id"   UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
        "route_id"     UUID                         NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
        "value"        INTEGER,

        PRIMARY KEY ("identifier", "period", "period_date", "service_id", "route_id")
      );
    ]],
  },

  mysql = {
    up = [[
      CREATE TABLE IF NOT EXISTS `response_ratelimiting_metrics` (
        `identifier` varchar(50) NOT NULL,
        `period` varchar(200) NOT NULL,
        `period_date` timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
        `service_id` varchar(50) NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
        `route_id` varchar(50) NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000',
        `value` int(11) DEFAULT NULL,
        PRIMARY KEY (`identifier`,`period`,`period_date`,`service_id`,`route_id`)
      );
    ]],
  },
}
