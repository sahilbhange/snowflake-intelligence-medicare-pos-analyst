-- ============================================================================
-- Grant All Required Privileges for AI Governance
-- Run as ACCOUNTADMIN (has both SECURITYADMIN and application role privileges)
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- 1. Schema and Object Privileges
-- ============================================================================

-- Grant schema privileges
GRANT USAGE ON DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Grant object creation privileges
GRANT CREATE TABLE ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT CREATE VIEW ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT CREATE PROCEDURE ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT CREATE TASK ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Grant warehouse privileges
GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT OPERATE ON WAREHOUSE COMPUTE_WH TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Grant EXECUTE TASK privilege (required to resume tasks)
GRANT EXECUTE TASK ON ACCOUNT TO ROLE MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- 2. AI Observability Access
-- ============================================================================

-- Grant AI Observability application role
-- This is required to access SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP
TO ROLE MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- Verify All Grants
-- ============================================================================

SHOW GRANTS TO ROLE MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- Test Access
-- ============================================================================

-- Switch to working role
USE ROLE MEDICARE_POS_INTELLIGENCE;

-- Test AI Observability access
SELECT COUNT(*) AS ai_event_count
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS
LIMIT 1;

-- Test schema access
SELECT 'All privileges granted successfully' AS status;
