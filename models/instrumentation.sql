-- Instrumentation tables for Analyst/Cortex logging and evals.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema ANALYTICS;

-- Analyst request/response logging.
create or replace table ANALYTICS.ANALYST_QUERY_LOG (
  query_id string,
  user_id string,
  question string,
  generated_sql string,
  response_tokens number,
  latency_ms number,
  success_flag boolean,
  created_at timestamp_ntz default current_timestamp()
);

create or replace table ANALYTICS.ANALYST_RESPONSE_LOG (
  query_id string,
  answer_summary string,
  fallback_used boolean,
  notes string,
  created_at timestamp_ntz default current_timestamp()
);

-- Evaluation prompts for regression checks.
create or replace table ANALYTICS.ANALYST_EVAL_SET (
  eval_id string,
  category string,
  question string,
  expected_pattern string,
  notes string,
  created_at timestamp_ntz default current_timestamp()
);
