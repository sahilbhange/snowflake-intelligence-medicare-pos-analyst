
-- ============================================================================
-- Create Governance Table
-- ============================================================================
USE ROLE MEDICARE_POS_INTELLIGENCE;

USE DATABASE MEDICARE_POS_DB;
USE SCHEMA GOVERNANCE;


CREATE TABLE IF NOT EXISTS GOVERNANCE.AI_AGENT_GOVERNANCE (
    request_id STRING,
    trace_id STRING,
    user_name STRING,
    role_name STRING,
    thread_id NUMBER,
    query_date DATE,
    query_hour NUMBER,
    agent_name STRING,
    agent_version NUMBER,
    database_name STRING,
    schema_name STRING,
    planning_model STRING,
    user_question STRING,
    agent_response STRING,
    question_category STRING,
    generated_sql STRING,
    tools_used ARRAY,
    tool_types ARRAY,
    used_verified_query BOOLEAN,
    total_duration_ms NUMBER,
    planning_duration_ms NUMBER,
    sql_generation_latency_ms NUMBER,
    performance_category STRING,
    input_tokens NUMBER,
    output_tokens NUMBER,
    total_tokens NUMBER,
    cache_read_tokens NUMBER,
    cache_write_tokens NUMBER,
    cache_hit_rate_pct FLOAT,
    estimated_cost_usd FLOAT,
    execution_status STRING,
    status_code STRING,
    is_successful BOOLEAN,
    start_timestamp TIMESTAMP,
    completion_timestamp TIMESTAMP,
    created_at TIMESTAMP,
    PRIMARY KEY (request_id)
);
