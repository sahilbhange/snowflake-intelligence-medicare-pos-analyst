-- ============================================================================
-- Scheduled Task for AI Governance Auto-Population
-- Runs daily to populate governance data from AI Observability events
-- ============================================================================

USE ROLE MEDICARE_POS_INTELLIGENCE;
USE DATABASE MEDICARE_POS_DB;
USE SCHEMA GOVERNANCE;

-- ============================================================================
-- Create Task to Auto-Populate Governance Data
-- ============================================================================

CREATE OR REPLACE TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 2 * * * America/Los_Angeles'  -- Daily at 2 AM PT
    COMMENT = 'Auto-populate AI governance data from last 7 days of AI Observability events'
AS
    CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(7);

-- Task is created in SUSPENDED state by default
-- Resume it to activate scheduling
ALTER TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH RESUME;

-- ============================================================================
-- Verify Task
-- ============================================================================

SHOW TASKS LIKE 'DAILY_AI_GOVERNANCE_REFRESH' IN SCHEMA GOVERNANCE;

-- Check task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    TASK_NAME => 'DAILY_AI_GOVERNANCE_REFRESH'
))
ORDER BY SCHEDULED_TIME DESC
LIMIT 10;

-- ============================================================================
-- Manual Execution (optional)
-- ============================================================================

-- If you need to run manually before scheduled time:
-- EXECUTE TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH;

-- To suspend task (stop auto-execution):
-- ALTER TASK GOVERNANCE.DAILY_AI_GOVERNANCE_REFRESH SUSPEND;
