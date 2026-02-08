-- ============================================================================
-- Simplified AI Governance: View + Stored Proc
-- FIXED: Extracts data from ALL span types (not just record_root)
-- ============================================================================
USE ROLE MEDICARE_POS_INTELLIGENCE;

USE DATABASE MEDICARE_POS_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- Create View for Governance Parameters
-- Joins multiple span types to get complete data
-- ============================================================================
CREATE OR REPLACE VIEW GOVERNANCE.V_AI_GOVERNANCE_PARAMS AS
WITH
-- Get root span (user question, response, status)
root_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,
        TIMESTAMP AS completion_timestamp,
        START_TIMESTAMP,
        RESOURCE_ATTRIBUTES:"snow.user.name"::STRING AS user_name,
        RESOURCE_ATTRIBUTES:"snow.session.role.primary.name"::STRING AS role_name,
        RECORD_ATTRIBUTES:"ai.observability.record_id"::STRING AS request_id,
        RECORD_ATTRIBUTES:"ai.observability.record_root.input"::STRING AS user_question,
        RECORD_ATTRIBUTES:"ai.observability.record_root.output"::STRING AS agent_response,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.thread_id"::NUMBER AS thread_id,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.duration"::NUMBER AS total_duration_ms,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.status"::STRING AS execution_status,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.status.code"::STRING AS status_code,
        RECORD_ATTRIBUTES:"snow.ai.observability.object.name"::STRING AS agent_name,
        RECORD_ATTRIBUTES:"snow.ai.observability.object.version.id"::NUMBER AS agent_version,
        RECORD_ATTRIBUTES:"snow.ai.observability.database.name"::STRING AS database_name,
        RECORD_ATTRIBUTES:"snow.ai.observability.schema.name"::STRING AS schema_name
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD_ATTRIBUTES:"ai.observability.span_type"::STRING = 'record_root'
),

-- Get planning/response generation span (model, tokens, SQL)
planning_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.model"::STRING AS planning_model,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.duration"::NUMBER AS planning_duration_ms,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.input"::NUMBER AS input_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.output"::NUMBER AS output_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.total"::NUMBER AS total_tokens,
        RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.cache_read_input"::NUMBER AS cache_read_tokens,
        -- Extract SQL and metadata from tool execution results (double-encoded JSON)
        -- First PARSE_JSON gets array, [0] gets first element (a JSON string), second PARSE_JSON parses that string
        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):sql::STRING AS generated_sql,
        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):verified_query_used::BOOLEAN AS used_verified_query,
        TRY_PARSE_JSON(
            TRY_PARSE_JSON(
                RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.tool_execution.results"::STRING
            )[0]::STRING
        ):analyst_latency_ms::NUMBER AS sql_generation_latency_ms
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD:name::STRING LIKE '%ResponseGeneration%'
),

-- Get tool execution information
tool_span AS (
    SELECT
        TRACE:trace_id::STRING AS trace_id,
        ARRAY_AGG(RECORD:name::STRING) AS tools_used,
        ARRAY_AGG(
            CASE
                WHEN RECORD:name::STRING LIKE '%CortexAnalyst%' THEN 'CortexAnalyst'
                WHEN RECORD:name::STRING LIKE '%Chart%' THEN 'ChartGeneration'
                ELSE SPLIT_PART(RECORD:name::STRING, '_', 1)
            END
        ) AS tool_types
    FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
    WHERE RECORD_TYPE = 'SPAN'
      AND RECORD:name::STRING LIKE '%Tool%'
    GROUP BY TRACE:trace_id::STRING
)

-- Combine all span data into one row per trace_id
SELECT
    -- Identity
    r.request_id,
    r.trace_id,
    r.user_name,
    r.role_name,
    r.thread_id,

    -- Agent info
    r.agent_name,
    r.agent_version,
    r.database_name,
    r.schema_name,
    p.planning_model,

    -- User interaction
    r.user_question,
    r.agent_response,

    -- Question category
    CASE
        WHEN LOWER(r.user_question) LIKE '%top%' OR LOWER(r.user_question) LIKE '%highest%' THEN 'ranking'
        WHEN LOWER(r.user_question) LIKE '%average%' OR LOWER(r.user_question) LIKE '%avg%' THEN 'aggregation'
        WHEN LOWER(r.user_question) LIKE '%what is%' OR LOWER(r.user_question) LIKE '%define%' THEN 'lookup'
        WHEN LOWER(r.user_question) LIKE '%compare%' THEN 'comparison'
        ELSE 'other'
    END AS question_category,

    -- Generated SQL
    p.generated_sql,
    p.used_verified_query,

    -- Tools
    COALESCE(t.tools_used, ARRAY_CONSTRUCT()) AS tools_used,
    COALESCE(t.tool_types, ARRAY_CONSTRUCT()) AS tool_types,

    -- Performance
    r.total_duration_ms,
    p.planning_duration_ms,
    p.sql_generation_latency_ms,
    CASE
        WHEN r.total_duration_ms > 10000 THEN 'needs_optimization'
        WHEN r.total_duration_ms > 5000 THEN 'slow'
        WHEN r.total_duration_ms > 2000 THEN 'moderate'
        ELSE 'fast'
    END AS performance_category,

    -- Tokens & cost
    p.input_tokens,
    p.output_tokens,
    p.total_tokens,
    p.cache_read_tokens,
    ROUND(p.cache_read_tokens * 100.0 / NULLIF(p.input_tokens, 0), 1) AS cache_hit_rate_pct,
    ROUND((p.total_tokens / 1000000.0) * 0.75, 4) AS estimated_cost_usd,

    -- Quality
    r.execution_status,
    r.status_code,
    CASE
        WHEN r.execution_status = 'SUCCESS' AND r.status_code = '200' THEN TRUE
        ELSE FALSE
    END AS is_successful,

    -- Timestamps
    r.completion_timestamp,
    r.START_TIMESTAMP AS start_timestamp,
    DATE(r.completion_timestamp) AS query_date,
    HOUR(r.completion_timestamp) AS query_hour,
    CURRENT_TIMESTAMP() AS created_at

FROM root_span r
LEFT JOIN planning_span p ON r.trace_id = p.trace_id
LEFT JOIN tool_span t ON r.trace_id = t.trace_id;


-- ============================================================================
-- Test the view
-- ============================================================================

-- Should now show planning_model, tokens, SQL populated
SELECT * FROM GOVERNANCE.V_AI_GOVERNANCE_PARAMS
WHERE trace_id = '22a37156c76c6464b3825c514b3ffb27';

-- ============================================================================
-- Simplified Stored Procedure
-- ============================================================================

CREATE OR REPLACE PROCEDURE GOVERNANCE.POPULATE_AI_GOVERNANCE(
    LOOKBACK_DAYS NUMBER DEFAULT 7
)
RETURNS STRING
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    INSERT INTO GOVERNANCE.AI_AGENT_GOVERNANCE
    SELECT
        request_id,
        trace_id,
        user_name,
        role_name,
        thread_id,
        query_date,
        query_hour,
        agent_name,
        agent_version,
        database_name,
        schema_name,
        planning_model,
        user_question,
        agent_response,
        question_category,
        generated_sql,
        tools_used,
        tool_types,
        used_verified_query,
        total_duration_ms,
        planning_duration_ms,
        sql_generation_latency_ms,
        performance_category,
        input_tokens,
        output_tokens,
        total_tokens,
        cache_read_tokens,
        0 AS cache_write_tokens,
        cache_hit_rate_pct,
        estimated_cost_usd,
        execution_status,
        status_code,
        is_successful,
        start_timestamp,
        completion_timestamp,
        created_at
    FROM GOVERNANCE.V_AI_GOVERNANCE_PARAMS
    WHERE query_date >= DATEADD(day, -:LOOKBACK_DAYS, CURRENT_DATE())
      AND request_id NOT IN (SELECT request_id FROM GOVERNANCE.AI_AGENT_GOVERNANCE);

    RETURN 'Successfully populated ' || SQLROWCOUNT || ' records';
END;
$$;


-- ============================================================================
CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(1);


--- Validate result
SELECT * FROM GOVERNANCE.AI_AGENT_GOVERNANCE
ORDER BY query_date DESC;



SELECT 
    RECORD:name::STRING AS span_name,
    RECORD_ATTRIBUTES AS all_attributes
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
WHERE TRACE:trace_id::STRING = '22a37156c76c6464b3825c514b3ffb27'
  AND RECORD:name::STRING LIKE '%Tool%'
LIMIT 5;


