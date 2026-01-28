-- ============================================================================
-- Query Instrumentation & Logging Infrastructure
-- ============================================================================
--
-- LEARN ABOUT THIS:
--   📖 Audit logging deep-dive: medium/claude/subarticle_3_trust_layer.md#audit-logging
--   📖 Instrumentation concept: medium/claude/subarticle_3_trust_layer.md#weekly-review-process
--   📚 Governance framework: docs/governance/semantic_model_lifecycle.md
--   📚 Human validation: docs/governance/human_validation_log.md
--
-- ============================================================================
-- PURPOSE:
-- Logs all Cortex Analyst queries (who asked what, when, SQL generated).
-- Enables compliance audits, cost attribution, and feedback collection.
-- Drives continuous improvement via query history analysis.
--
-- ============================================================================

-- Instrumentation tables for Analyst/Cortex logging and evals.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema INTELLIGENCE;

-- Analyst request/response logging.
create or replace table INTELLIGENCE.ANALYST_QUERY_LOG (
  query_id string,
  user_id string,
  question string,
  generated_sql string,
  response_tokens number,
  latency_ms number,
  success_flag boolean,
  created_at timestamp_ntz default current_timestamp()
);

create or replace table INTELLIGENCE.ANALYST_RESPONSE_LOG (
  query_id string,
  answer_summary string,
  fallback_used boolean,
  notes string,
  created_at timestamp_ntz default current_timestamp()
);

-- Evaluation prompts for regression checks.
create or replace table INTELLIGENCE.ANALYST_EVAL_SET (
  eval_id string,
  category string,
  question string,
  expected_pattern string,
  notes string,
  created_at timestamp_ntz default current_timestamp()
);
