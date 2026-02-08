-- ============================================================================
-- Grant Access to AI Observability Events via Application Role
-- Run as ACCOUNTADMIN
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Grant the AI Observability application role to your working role
-- This is the correct way to access AI_OBSERVABILITY_EVENTS table
GRANT APPLICATION ROLE SNOWFLAKE.AI_OBSERVABILITY_EVENTS_LOOKUP
TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Verify grants
SHOW GRANTS TO ROLE MEDICARE_POS_INTELLIGENCE;

-- Switch back to working role
USE ROLE MEDICARE_POS_INTELLIGENCE;

-- Test access
SELECT COUNT(*) AS event_count
FROM SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS;

SELECT 'AI Observability access granted successfully' AS status;
