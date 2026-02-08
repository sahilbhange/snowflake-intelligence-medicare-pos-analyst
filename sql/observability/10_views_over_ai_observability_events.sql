-- ============================================================================
-- Helper Views Over SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
-- ============================================================================
--
-- Purpose:
--   Make AI Observability traces easier to query alongside this repo’s
--   governance / validation tables.
--
-- Prereq:
--   Role running these queries needs:
--     GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP ...
--
-- Docs:
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/reference
--
-- ============================================================================

USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA OBSERVABILITY;

-- Raw passthrough (handy for ad-hoc spelunking).
CREATE OR REPLACE VIEW OBSERVABILITY.AI_OBSERVABILITY_EVENTS_RAW AS
SELECT *
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS;

-- select * from OBSERVABILITY.AI_OBSERVABILITY_EVENTS_RAW limit 100;

-- Root spans are the easiest way to read “one record per app invocation”.
CREATE OR REPLACE VIEW OBSERVABILITY.AI_OBSERVABILITY_ROOT_SPANS AS
SELECT
  TIMESTAMP AS event_ts,
  START_TIMESTAMP AS start_ts,
  RECORD_TYPE,
  RECORD:"name"::STRING AS span_name,
  -- Common keys (null if not present). Prefer TruLens keys, fall back to Cortex Agent keys.
  COALESCE(
    RECORD_ATTRIBUTES:"ai.observability.app_name"::STRING,
    RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING
  ) AS app_name,
  RECORD_ATTRIBUTES:"ai.observability.app_version"::STRING AS app_version,
  COALESCE(
    RECORD_ATTRIBUTES:"trulens.record.id"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.record_id"::STRING
  ) AS record_id,
  RECORD_ATTRIBUTES:"ai.observability.input_id"::STRING AS input_id,
  RECORD_ATTRIBUTES:"request_id"::STRING AS request_id,
  COALESCE(
    RECORD_ATTRIBUTES:"trulens.record.root.input"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.record_root.input"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.input"::STRING
  ) AS input_text,
  COALESCE(
    RECORD_ATTRIBUTES:"trulens.record.root.output"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.record_root.output"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.output"::STRING
  ) AS output_text,
  COALESCE(
    RECORD_ATTRIBUTES:"trulens.record.root.ground_truth_output"::STRING,
    RECORD_ATTRIBUTES:"ai.observability.record_root.ground_truth_output"::STRING
  ) AS ground_truth_text,
  COALESCE(
    RECORD_ATTRIBUTES:"trulens.record.root.retrieved_context",
    RECORD_ATTRIBUTES:"ai.observability.record_root.retrieved_context"
  ) AS retrieved_context,
  RECORD_ATTRIBUTES:"snow.ai.observability.object.type"::STRING AS object_type,
  RECORD_ATTRIBUTES:"snow.ai.observability.database.name"::STRING AS database_name,
  RECORD_ATTRIBUTES:"snow.ai.observability.schema.name"::STRING AS schema_name,
  RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING AS object_name,
  RESOURCE_ATTRIBUTES,
  RECORD_ATTRIBUTES
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE RECORD_TYPE = 'SPAN'
  AND (
    RECORD_ATTRIBUTES:"trulens.record.root.input" IS NOT NULL
    OR RECORD_ATTRIBUTES:"ai.observability.record_root.input" IS NOT NULL
    OR RECORD_ATTRIBUTES:"ai.observability.record_id" IS NOT NULL
  );

-- select * from OBSERVABILITY.AI_OBSERVABILITY_ROOT_SPANS limit 100;


-- Flattened spans for deeper debugging (child spans, retrieval/generation, etc).
CREATE OR REPLACE VIEW OBSERVABILITY.AI_OBSERVABILITY_SPANS AS
SELECT
  e.TIMESTAMP AS event_ts,
  e.START_TIMESTAMP AS start_ts,
  e.RECORD_TYPE,
  COALESCE(
    e.RECORD_ATTRIBUTES:"ai.observability.app_name"::STRING,
    e.RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING
  ) AS app_name,
  e.RECORD_ATTRIBUTES:"ai.observability.app_version"::STRING AS app_version,
  v:"trace_id"::STRING AS trace_id,
  v:"span_id"::STRING AS span_id,
  v:"parent_id"::STRING AS parent_span_id,
  v:"name"::STRING AS span_name,
  v:"attributes" AS span_attributes,
  e.RESOURCE_ATTRIBUTES,
  e.RECORD_ATTRIBUTES
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS e,
  LATERAL FLATTEN(input => COALESCE(e.RECORD_ATTRIBUTES:"trulens.record.span", ARRAY_CONSTRUCT(e.RECORD))) s,
  LATERAL (SELECT s.value::VARIANT AS v);

-- Flattened request-level view (one row per request_id)
CREATE OR REPLACE VIEW OBSERVABILITY.AI_OBSERVABILITY_AGENT_REQUESTS AS
WITH base AS (
  SELECT
    TIMESTAMP AS event_ts,
    RECORD_ATTRIBUTES AS ra
  FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
  WHERE RECORD_TYPE = 'SPAN'
),
normalized AS (
  SELECT
    event_ts,
    COALESCE(
      ra:"request_id"::STRING,
      ra:"snow.ai.observability.agent.tool.cortex_analyst.request_id"::STRING,
      ra:"snow.ai.observability.agent.tool.sql_execution.request_id"::STRING
    ) AS request_id,
    ra
  FROM base
)
SELECT
  request_id,
  MIN(event_ts) AS first_event_ts,
  MAX(event_ts) AS last_event_ts,
  MAX(COALESCE(
    ra:"ai.observability.record_root.input"::STRING,
    TRY_PARSE_JSON(
      TRY_PARSE_JSON(ra:"snow.ai.observability.agent.tool.cortex_analyst.messages"::STRING)[0]::STRING
    ):"content"[0]:"text"::STRING
  )) AS question,
  MAX(COALESCE(
    ra:"ai.observability.record_root.output"::STRING,
    ra:"snow.ai.observability.agent.tool.cortex_analyst.text"::STRING
  )) AS answer_summary,
  MAX(ra:"snow.ai.observability.agent.tool.cortex_analyst.sql_query"::STRING) AS analyst_sql,
  MAX(ra:"snow.ai.observability.agent.tool.sql_execution.query"::STRING) AS executed_sql,
  MAX(ra:"snow.ai.observability.agent.tool.cortex_analyst.status"::STRING) AS analyst_status,
  MAX(ra:"snow.ai.observability.agent.tool.cortex_analyst.status.description"::STRING) AS analyst_status_description,
  MAX(ra:"snow.ai.observability.agent.tool.sql_execution.status"::STRING) AS execution_status,
  MAX(ra:"snow.ai.observability.agent.tool.sql_execution.status.description"::STRING) AS execution_status_description,
  MAX(ra:"snow.ai.observability.object.name"::STRING) AS object_name,
  MAX(ra:"snow.ai.observability.object.type"::STRING) AS object_type,
  MAX(ra:"snow.ai.observability.schema.name"::STRING) AS schema_name,
  MAX(ra:"snow.ai.observability.database.name"::STRING) AS database_name
FROM normalized
WHERE request_id IS NOT NULL
GROUP BY request_id;

select * from OBSERVABILITY.AI_OBSERVABILITY_AGENT_REQUESTS
where request_id = 'cf36e73d-0835-48bc-a5d6-d103207bcbf2'
limit 10;


