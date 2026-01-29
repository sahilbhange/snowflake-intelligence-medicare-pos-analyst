-- ============================================================================
-- Complete Teardown: Drop All Deployment Objects
-- ============================================================================
--
-- WARNING: This script will permanently delete:
--   ✅ Cortex Agent
--   ✅ All Cortex Search services
--   ✅ All tables, views, and schemas
--   ✅ The entire MEDICARE_POS_DB database
--
-- Use this to reset the deployment and start fresh.
-- ALL DATA WILL BE LOST. This action cannot be undone.
--
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- Step 1: Drop Cortex Agent (if exists)
-- ============================================================================
-- Note: Agent must be dropped before associated semantic model stage is dropped

DROP AGENT IF EXISTS MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL;

-- ============================================================================
-- Step 2: Drop Cortex Search Services (if exists)
-- ============================================================================
-- Services must be dropped individually by schema

DROP CORTEX SEARCH SERVICE IF EXISTS MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC;
DROP CORTEX SEARCH SERVICE IF EXISTS MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC;
DROP CORTEX SEARCH SERVICE IF EXISTS MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC;
DROP CORTEX SEARCH SERVICE IF EXISTS MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC;

-- ============================================================================
-- Step 3: Drop All Schemas in the Database (if exists)
-- ============================================================================
-- Dropping the database will cascade drop all schemas, but we explicitly
-- drop schemas to be thorough and clear about what's happening.

DROP SCHEMA IF EXISTS MEDICARE_POS_DB.RAW CASCADE;
DROP SCHEMA IF EXISTS MEDICARE_POS_DB.CURATED CASCADE;
DROP SCHEMA IF EXISTS MEDICARE_POS_DB.ANALYTICS CASCADE;
DROP SCHEMA IF EXISTS MEDICARE_POS_DB.SEARCH CASCADE;
DROP SCHEMA IF EXISTS MEDICARE_POS_DB.INTELLIGENCE CASCADE;
DROP SCHEMA IF EXISTS MEDICARE_POS_DB.GOVERNANCE CASCADE;

-- ============================================================================
-- Step 4: Drop Warehouse (if exists)
-- ============================================================================

DROP WAREHOUSE IF EXISTS MEDICARE_POS_WH;

-- ============================================================================
-- Step 5: Drop Roles (if exists)
-- ============================================================================

DROP ROLE IF EXISTS MEDICARE_POS_ADMIN;
DROP ROLE IF EXISTS MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- Step 6: Drop Database (if exists)
-- ============================================================================
-- This ensures everything is cleaned up

DROP DATABASE IF EXISTS MEDICARE_POS_DB;

-- ============================================================================
-- Verification
-- ============================================================================

SELECT '✅ Teardown complete!' AS status;
SELECT '⚠️  All deployment objects have been dropped.' AS warning;
SELECT '📝 To redeploy, run: make demo' AS next_steps;

-- ============================================================================
-- Summary of Deleted Objects
-- ============================================================================
/*
Deleted:
  ✅ Database: MEDICARE_POS_DB (and all schemas)
     - RAW (raw data tables)
     - CURATED (cleaned, typed data)
     - ANALYTICS (business-ready views)
     - SEARCH (Cortex Search services)
     - INTELLIGENCE (logging, eval, validation)
     - GOVERNANCE (metadata, quality, lineage)

  ✅ Warehouse: MEDICARE_POS_WH

  ✅ Roles:
     - MEDICARE_POS_ADMIN
     - MEDICARE_POS_INTELLIGENCE

  ✅ Cortex Objects:
     - Agent: DMEPOS_INTELLIGENCE_AGENT_SQL
     - Search Services: HCPCS_SEARCH_SVC, DEVICE_SEARCH_SVC, PROVIDER_SEARCH_SVC, PDF_SEARCH_SVC

Local files still exist in:
  ✅ data/ - Downloaded CMS/FDA data (can be reused)
  ✅ sql/ - SQL deployment scripts (unchanged)
  ✅ models/ - Semantic models (unchanged)

To redeploy from scratch:
  $ make demo          # Fresh installation
  $ make deploy-all    # Full production setup
*/
