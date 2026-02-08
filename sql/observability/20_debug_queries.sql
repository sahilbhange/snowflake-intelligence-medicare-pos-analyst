-- ============================================================================
-- AI Observability debug queries (quick sanity checks)
-- ============================================================================

-- 1) Raw sample event rows (check column names and shape)
SELECT *
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
LIMIT 5;

-- 2) Root-span style events (TruLens + Cortex Agent compatible)
SELECT *
FROM MEDICARE_POS_DB.OBSERVABILITY.AI_OBSERVABILITY_ROOT_SPANS
ORDER BY event_ts DESC
LIMIT 100;

-- 3) Span-level view with TRACE ids (works for Cortex Agent events)
SELECT
  e.TIMESTAMP AS event_ts,
  e.START_TIMESTAMP AS start_ts,
  e.RECORD_TYPE,
  e.TRACE:"trace_id"::STRING AS trace_id,
  e.TRACE:"span_id"::STRING AS span_id,
  e.RECORD:"name"::STRING AS span_name,
  COALESCE(
    e.RECORD_ATTRIBUTES:"ai.observability.app_name"::STRING,
    e.RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING
  ) AS app_name,
  e.RECORD_ATTRIBUTES:"ai.observability.app_version"::STRING AS app_version,
  e.RECORD_ATTRIBUTES:"request_id"::STRING AS request_id,
  e.RECORD_ATTRIBUTES:"ai.observability.input_id"::STRING AS input_id,
  e.RECORD_ATTRIBUTES:"snow.ai.observability.object.type"::STRING AS object_type,
  e.RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING AS object_name,
  e.RESOURCE_ATTRIBUTES,
  e.RECORD_ATTRIBUTES
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS e
WHERE e.RECORD_TYPE = 'SPAN'
ORDER BY event_ts DESC
LIMIT 200;

-- 4) Quick schema discovery for RECORD_ATTRIBUTES keys
SELECT
  TIMESTAMP AS event_ts,
  COALESCE(
    RECORD_ATTRIBUTES:"ai.observability.app_name"::STRING,
    RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING
  ) AS app_name,
  OBJECT_KEYS(RECORD_ATTRIBUTES) AS record_attribute_keys
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
ORDER BY event_ts DESC
LIMIT 20;
