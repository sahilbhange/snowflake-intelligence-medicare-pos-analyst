-- ============================================================================
-- Snowflake Cortex AI Observability: Prereqs + Grants (Template)
-- ============================================================================
--
-- Purpose:
--   Minimal privileges to:
--   1) emit AI Observability traces (TruLens -> Snowflake)
--   2) query SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
--   3) create/run server-side evaluation runs (tasks + external agent objects)
--
-- Notes:
--   * Most of these require ACCOUNTADMIN/SECURITYADMIN.
--   * Replace <TARGET_ROLE>, <DB>, <SCHEMA> with your values.
--
-- Docs:
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability
--   https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/reference
--
-- ============================================================================

USE ROLE SECURITYADMIN;

-- ============================================================================
-- AI Observability grants for MEDICARE_POS_INTELLIGENCE
-- ============================================================================

-- NOTE:
--   Grants on MEDICARE_POS_DB.OBSERVABILITY require the schema to exist.
--   Create it first (either run 10_views_over_ai_observability_events.sql
--   or uncomment the CREATE SCHEMA below).

-- CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.OBSERVABILITY;

-- Allow Cortex model usage for evaluations.
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Allow AI Observability event lookup (required).
GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Optional UI role (may not exist in all accounts/regions).
-- If this fails, skip it or ask your Snowflake admin which AI Observability
-- application roles are available in your account.
-- GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_VIEWER TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Allow creating AI Observability external agent objects and tasks.
GRANT CREATE EXTERNAL AGENT ON SCHEMA MEDICARE_POS_DB.INTELLIGENCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT CREATE TASK ON SCHEMA MEDICARE_POS_DB.INTELLIGENCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Allow querying the OBSERVABILITY schema views created in this repo.
GRANT USAGE ON DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.OBSERVABILITY TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT ON ALL VIEWS IN SCHEMA MEDICARE_POS_DB.OBSERVABILITY TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MEDICARE_POS_DB.OBSERVABILITY TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT CREATE VIEW ON SCHEMA MEDICARE_POS_DB.OBSERVABILITY TO ROLE MEDICARE_POS_INTELLIGENCE;
