
-- ============================================================================
-- Flatten AI Observability events into one row per request_id
-- ============================================================================

select TRACE:"trace_id"::string as trace_id,* from SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS 
where trace_id = '22a37156c76c6464b3825c514b3ffb27'
order by timestamp::TIMESTAMP desc
limit 100;