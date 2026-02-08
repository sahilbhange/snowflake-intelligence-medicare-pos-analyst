-- ============================================================================
-- AI Observability Setup for Semantic Analyst Validation
-- Snowflake Intelligence Medicare POS Analyst Project
-- ============================================================================

-- ============================================================================
-- 1. GRANT REQUIRED PRIVILEGES
-- ============================================================================

-- Grant Cortex user role
GRANT CORTEX_USER ON DATABASE SNOWFLAKE TO ROLE ANALYST_ROLE;

-- Grant AI Observability application role
GRANT APPLICATION ROLE AI_OBSERVABILITY_EVENTS_LOOKUP TO ROLE ANALYST_ROLE;

-- Grant schema privileges
GRANT CREATE EXTERNAL AGENT ON SCHEMA INTELLIGENCE TO ROLE ANALYST_ROLE;
GRANT CREATE TASK ON SCHEMA INTELLIGENCE TO ROLE ANALYST_ROLE;
GRANT CREATE EVENT TABLE ON SCHEMA INTELLIGENCE TO ROLE ANALYST_ROLE;


-- ============================================================================
-- 2. CREATE EVENT TABLE FOR AI OBSERVABILITY
-- ============================================================================

USE DATABASE MEDICARE_POS;
USE SCHEMA INTELLIGENCE;

-- Create event table to store AI Observability traces and metrics
CREATE EVENT TABLE IF NOT EXISTS INTELLIGENCE.AI_OBSERVABILITY_EVENTS;

-- Verify event table
SHOW EVENT TABLES IN SCHEMA INTELLIGENCE;


-- ============================================================================
-- 3. SEMANTIC MODEL METADATA TABLE (for context retrieval)
-- ============================================================================

CREATE TABLE IF NOT EXISTS INTELLIGENCE.SEMANTIC_MODEL_METADATA (
    measure_name STRING,
    measure_type STRING,              -- 'dimension', 'measure', 'filter'
    description STRING,
    synonyms ARRAY,                   -- Alternative names users might use
    example_values ARRAY,
    data_type STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Seed with DMEPOS semantic model metadata
INSERT INTO INTELLIGENCE.SEMANTIC_MODEL_METADATA VALUES
    ('provider_state', 'dimension',
     'US state where the provider is located. Use for geographic analysis.',
     ['state', 'location', 'geography', 'region'],
     ['CA', 'TX', 'FL', 'NY'],
     'STRING', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

    ('hcpcs_code', 'dimension',
     'Healthcare Common Procedure Coding System code for medical devices.',
     ['device code', 'product code', 'procedure code'],
     ['E1390', 'K0738', 'E0424'],
     'STRING', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

    ('total_supplier_claims', 'measure',
     'Total number of claims submitted by suppliers. Use for volume analysis.',
     ['claim count', 'number of claims', 'claim volume'],
     [1000, 5000, 10000],
     'NUMBER', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

    ('avg_supplier_medicare_payment', 'measure',
     'Average Medicare payment amount per claim. Use for financial analysis.',
     ['average payment', 'payment amount', 'reimbursement'],
     [125.50, 250.00, 500.75],
     'NUMBER', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()),

    ('referring_npi', 'dimension',
     'National Provider Identifier for the referring physician.',
     ['provider ID', 'NPI', 'physician ID'],
     ['1234567890', '9876543210'],
     'NUMBER', CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());


-- ============================================================================
-- 4. ENHANCED VIEWS FOR UNIFIED ANALYTICS
-- ============================================================================

-- View: AI Observability results with friendly names
CREATE OR REPLACE VIEW INTELLIGENCE.SEMANTIC_ANALYST_QUALITY AS
SELECT
    event_id,
    app_name,
    app_version,
    -- Extract from span attributes
    GET(span_attributes, 'input_prompt')::STRING AS user_question,
    GET(span_attributes, 'output_response')::STRING AS generated_sql,
    -- Quality metrics
    GET(span_attributes, 'answer_relevance_score')::FLOAT AS answer_relevance_score,
    GET(span_attributes, 'groundedness_score')::FLOAT AS groundedness_score,
    GET(span_attributes, 'context_relevance_score')::FLOAT AS context_relevance_score,
    -- Performance
    GET(span_attributes, 'latency_ms')::NUMBER AS latency_ms,
    GET(span_attributes, 'token_count')::NUMBER AS token_count,
    -- Debugging
    trace_id,
    span_id,
    span_type,
    event_timestamp
FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
WHERE app_name = 'DMEPOS_SEMANTIC_ANALYST';


-- View: Unified query analytics (existing logs + AI Observability)
CREATE OR REPLACE VIEW INTELLIGENCE.UNIFIED_QUERY_ANALYTICS AS
SELECT
    -- Existing query log fields
    l.query_id,
    l.user_id,
    l.question,
    l.generated_sql,
    l.success_flag,
    l.semantic_model_version,
    l.created_at,
    -- AI Observability metrics
    o.answer_relevance_score,
    o.groundedness_score,
    o.context_relevance_score,
    o.latency_ms,
    -- Human feedback
    f.feedback_type,
    f.feedback_text,
    f.priority,
    -- Combined quality score
    CASE
        WHEN o.answer_relevance_score IS NOT NULL THEN
            (o.answer_relevance_score + o.groundedness_score + o.context_relevance_score) / 3
        ELSE NULL
    END AS avg_quality_score
FROM INTELLIGENCE.ANALYST_QUERY_LOG l
LEFT JOIN INTELLIGENCE.SEMANTIC_ANALYST_QUALITY o
    ON l.query_id = o.trace_id
LEFT JOIN INTELLIGENCE.SEMANTIC_FEEDBACK f
    ON l.query_id = f.query_log_id;


-- ============================================================================
-- 5. MONITORING QUERIES
-- ============================================================================

-- Query: Daily quality metrics
CREATE OR REPLACE VIEW INTELLIGENCE.DAILY_QUALITY_METRICS AS
SELECT
    app_version,
    DATE(event_timestamp) AS metric_date,
    COUNT(*) AS total_queries,
    AVG(answer_relevance_score) AS avg_relevance,
    AVG(groundedness_score) AS avg_groundedness,
    AVG(context_relevance_score) AS avg_context,
    AVG(latency_ms) AS avg_latency_ms,
    SUM(CASE WHEN answer_relevance_score < 0.7 THEN 1 ELSE 0 END) AS low_quality_count,
    ROUND(SUM(CASE WHEN answer_relevance_score >= 0.7 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pass_rate_pct
FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
GROUP BY app_version, DATE(event_timestamp)
ORDER BY metric_date DESC;


-- Query: Weekly drift detection
CREATE OR REPLACE VIEW INTELLIGENCE.WEEKLY_QUALITY_DRIFT AS
WITH weekly_metrics AS (
    SELECT
        app_version,
        AVG(answer_relevance_score) AS current_relevance,
        AVG(groundedness_score) AS current_groundedness,
        COUNT(*) AS query_count
    FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
    WHERE event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
    GROUP BY app_version
),
baseline_metrics AS (
    SELECT
        app_version,
        AVG(answer_relevance_score) AS baseline_relevance,
        AVG(groundedness_score) AS baseline_groundedness
    FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
    WHERE event_timestamp BETWEEN DATEADD(day, -30, CURRENT_TIMESTAMP())
                              AND DATEADD(day, -8, CURRENT_TIMESTAMP())
    GROUP BY app_version
)
SELECT
    w.app_version,
    w.query_count,
    w.current_relevance,
    b.baseline_relevance,
    ROUND((w.current_relevance - b.baseline_relevance) / NULLIF(b.baseline_relevance, 0) * 100, 1) AS relevance_pct_change,
    w.current_groundedness,
    b.baseline_groundedness,
    ROUND((w.current_groundedness - b.baseline_groundedness) / NULLIF(b.baseline_groundedness, 0) * 100, 1) AS groundedness_pct_change,
    CASE
        WHEN w.current_relevance < 0.7 THEN 'CRITICAL: Quality below threshold'
        WHEN ABS((w.current_relevance - b.baseline_relevance) / NULLIF(b.baseline_relevance, 0)) > 0.1
            THEN 'WARNING: 10%+ drift from baseline'
        ELSE 'OK'
    END AS alert_status
FROM weekly_metrics w
JOIN baseline_metrics b ON w.app_version = b.app_version;


-- Query: Low-performing questions (for improvement)
CREATE OR REPLACE VIEW INTELLIGENCE.LOW_QUALITY_QUESTIONS AS
SELECT
    user_question,
    app_version,
    COUNT(*) AS occurrence_count,
    AVG(answer_relevance_score) AS avg_relevance,
    AVG(groundedness_score) AS avg_groundedness,
    MIN(answer_relevance_score) AS min_relevance,
    ARRAY_AGG(generated_sql) AS sql_variations
FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
WHERE event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND answer_relevance_score < 0.7
GROUP BY user_question, app_version
ORDER BY occurrence_count DESC, avg_relevance ASC
LIMIT 20;


-- ============================================================================
-- 6. AUTOMATED ALERTING TASKS
-- ============================================================================

-- Task: Daily quality check (runs every morning at 6 AM)
CREATE OR REPLACE TASK INTELLIGENCE.DAILY_QUALITY_CHECK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 6 * * * America/Los_Angeles'
AS
INSERT INTO INTELLIGENCE.QUALITY_ALERTS (alert_type, alert_message, severity, created_at)
SELECT
    'DAILY_QUALITY' AS alert_type,
    'Quality metrics for ' || app_version || ': ' ||
    'Pass rate ' || pass_rate_pct || '%, ' ||
    'Low quality count: ' || low_quality_count AS alert_message,
    CASE
        WHEN pass_rate_pct < 70 THEN 'CRITICAL'
        WHEN pass_rate_pct < 85 THEN 'WARNING'
        ELSE 'INFO'
    END AS severity,
    CURRENT_TIMESTAMP() AS created_at
FROM INTELLIGENCE.DAILY_QUALITY_METRICS
WHERE metric_date = CURRENT_DATE()
  AND pass_rate_pct < 95;  -- Only alert if below 95%

-- Enable task
-- ALTER TASK INTELLIGENCE.DAILY_QUALITY_CHECK RESUME;


-- Task: Weekly drift alert (runs every Monday at 7 AM)
CREATE OR REPLACE TASK INTELLIGENCE.WEEKLY_DRIFT_CHECK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 7 * * MON America/Los_Angeles'
AS
INSERT INTO INTELLIGENCE.QUALITY_ALERTS (alert_type, alert_message, severity, created_at)
SELECT
    'WEEKLY_DRIFT' AS alert_type,
    'Quality drift detected for ' || app_version || ': ' ||
    'Relevance changed ' || relevance_pct_change || '%, ' ||
    'Status: ' || alert_status AS alert_message,
    CASE
        WHEN alert_status LIKE 'CRITICAL%' THEN 'CRITICAL'
        WHEN alert_status LIKE 'WARNING%' THEN 'WARNING'
        ELSE 'INFO'
    END AS severity,
    CURRENT_TIMESTAMP() AS created_at
FROM INTELLIGENCE.WEEKLY_QUALITY_DRIFT
WHERE alert_status != 'OK';

-- Enable task
-- ALTER TASK INTELLIGENCE.WEEKLY_DRIFT_CHECK RESUME;


-- ============================================================================
-- 7. QUALITY ALERTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS INTELLIGENCE.QUALITY_ALERTS (
    alert_id STRING DEFAULT UUID_STRING(),
    alert_type STRING,        -- 'DAILY_QUALITY', 'WEEKLY_DRIFT', 'LOW_SCORE'
    alert_message STRING,
    severity STRING,          -- 'CRITICAL', 'WARNING', 'INFO'
    status STRING DEFAULT 'OPEN',  -- 'OPEN', 'ACKNOWLEDGED', 'RESOLVED'
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    acknowledged_at TIMESTAMP_NTZ,
    acknowledged_by STRING,
    resolved_at TIMESTAMP_NTZ,
    notes STRING
);


-- ============================================================================
-- 8. VERSION COMPARISON STORED PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE INTELLIGENCE.COMPARE_MODEL_VERSIONS(
    VERSION_A STRING,
    VERSION_B STRING
)
RETURNS TABLE (
    metric STRING,
    version_a_value FLOAT,
    version_b_value FLOAT,
    difference FLOAT,
    pct_change FLOAT
)
LANGUAGE SQL
AS
$$
BEGIN
    LET result_table RESULTSET := (
        WITH version_a_metrics AS (
            SELECT
                AVG(answer_relevance_score) AS avg_relevance,
                AVG(groundedness_score) AS avg_groundedness,
                AVG(context_relevance_score) AS avg_context,
                AVG(latency_ms) AS avg_latency
            FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
            WHERE app_version = :VERSION_A
              AND event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
        ),
        version_b_metrics AS (
            SELECT
                AVG(answer_relevance_score) AS avg_relevance,
                AVG(groundedness_score) AS avg_groundedness,
                AVG(context_relevance_score) AS avg_context,
                AVG(latency_ms) AS avg_latency
            FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
            WHERE app_version = :VERSION_B
              AND event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
        )
        SELECT 'answer_relevance' AS metric,
               a.avg_relevance AS version_a_value,
               b.avg_relevance AS version_b_value,
               b.avg_relevance - a.avg_relevance AS difference,
               ROUND((b.avg_relevance - a.avg_relevance) / NULLIF(a.avg_relevance, 0) * 100, 2) AS pct_change
        FROM version_a_metrics a, version_b_metrics b
        UNION ALL
        SELECT 'groundedness',
               a.avg_groundedness, b.avg_groundedness,
               b.avg_groundedness - a.avg_groundedness,
               ROUND((b.avg_groundedness - a.avg_groundedness) / NULLIF(a.avg_groundedness, 0) * 100, 2)
        FROM version_a_metrics a, version_b_metrics b
        UNION ALL
        SELECT 'context_relevance',
               a.avg_context, b.avg_context,
               b.avg_context - a.avg_context,
               ROUND((b.avg_context - a.avg_context) / NULLIF(a.avg_context, 0) * 100, 2)
        FROM version_a_metrics a, version_b_metrics b
        UNION ALL
        SELECT 'latency_ms',
               a.avg_latency, b.avg_latency,
               b.avg_latency - a.avg_latency,
               ROUND((b.avg_latency - a.avg_latency) / NULLIF(a.avg_latency, 0) * 100, 2)
        FROM version_a_metrics a, version_b_metrics b
    );
    RETURN TABLE(result_table);
END;
$$;

-- Usage: CALL INTELLIGENCE.COMPARE_MODEL_VERSIONS('v1.3.2', 'v1.4.0');


-- ============================================================================
-- 9. VERIFICATION QUERIES
-- ============================================================================

-- Verify setup
SELECT 'Event table exists' AS check_name,
       COUNT(*) > 0 AS passed
FROM INFORMATION_SCHEMA.EVENT_TABLES
WHERE table_schema = 'INTELLIGENCE'
  AND table_name = 'AI_OBSERVABILITY_EVENTS'

UNION ALL

SELECT 'Semantic metadata populated',
       COUNT(*) >= 5
FROM INTELLIGENCE.SEMANTIC_MODEL_METADATA

UNION ALL

SELECT 'Views created',
       COUNT(*) >= 4
FROM INFORMATION_SCHEMA.VIEWS
WHERE table_schema = 'INTELLIGENCE'
  AND table_name IN ('SEMANTIC_ANALYST_QUALITY', 'UNIFIED_QUERY_ANALYTICS',
                     'DAILY_QUALITY_METRICS', 'WEEKLY_QUALITY_DRIFT');


-- ============================================================================
-- 10. SAMPLE QUERIES FOR TESTING
-- ============================================================================

-- Check recent AI Observability events
SELECT *
FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
ORDER BY event_timestamp DESC
LIMIT 10;

-- Check quality metrics for last 7 days
SELECT *
FROM INTELLIGENCE.DAILY_QUALITY_METRICS
WHERE metric_date > DATEADD(day, -7, CURRENT_DATE())
ORDER BY metric_date DESC;

-- Check for drift alerts
SELECT *
FROM INTELLIGENCE.WEEKLY_QUALITY_DRIFT;

-- Find low-quality questions to improve
SELECT *
FROM INTELLIGENCE.LOW_QUALITY_QUESTIONS
LIMIT 10;

-- Check active alerts
SELECT *
FROM INTELLIGENCE.QUALITY_ALERTS
WHERE status = 'OPEN'
ORDER BY severity DESC, created_at DESC;
