use role MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- Cortex Agent for Medicare DMEPOS Analytics
-- ============================================================================
--
-- LEARN ABOUT THIS:
--   📖 Concept overview: medium/claude/subarticle_1_intelligence_layer.md
--   📚 Reference guide: docs/reference/cortex_agent_creation.md
--   📚 Agent routing: docs/reference/agent_guidance.md
--   🚀 Getting started: docs/implementation/getting-started.md
--
-- ============================================================================
-- BEFORE RUNNING:
-- 1. Ensure semantic model uploaded: @MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG
-- 2. Ensure all Cortex Search services created (HCPCS, Device, Provider, PDF)
-- 3. Update paths if your database/schema names differ
--
-- ============================================================================

USE DATABASE MEDICARE_POS_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- Step 1: Create stage for semantic model (if not exists)
-- ============================================================================
CREATE STAGE IF NOT EXISTS ANALYTICS.CORTEX_SEM_MODEL_STG
  COMMENT = 'Semantic model YAML files for Cortex Analyst';

-- Upload semantic model to stage using SnowSQL or Snowsight:
-- PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify upload:
-- LIST @ANALYTICS.CORTEX_SEM_MODEL_STG;

-- ============================================================================
-- Step 2: Create Cortex Agent
-- ============================================================================
CREATE OR REPLACE AGENT DMEPOS_INTELLIGENCE_AGENT_SQL
  COMMENT = 'Natural-language exploration of Medicare DMEPOS data by combining semantic search and governed analytics.'
  FROM SPECIFICATION
$$
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 300

instructions:
  orchestration: |
    You are a data assistant for Medicare DMEPOS analytics. You have access to:

    * Cortex Analyst semantic model for quantitative claims analysis (aggregations, rankings, metrics).
    * Four Cortex Search tools for lookups: HCPCS codes, medical devices/brands, providers/specialties, and CMS policy PDFs.

    Tool selection rules:

    1. Use Cortex Search when the user asks for definitions, descriptions, lookups, or fuzzy matching (e.g., “what is/define/meaning”, “codes related to…”, “device like…”, “find providers who…”, “policy/guidance for…”).
       * If the question mentions a HCPCS code or “billing code”, prefer HCPCS Search.
       * If it mentions device names, brand, model/version, manufacturer, or catalog, prefer Device Search.
       * If it mentions providers, NPI, specialty, or location-based provider discovery, prefer Provider Search.
       * If it mentions policy rules, documentation, fee schedule guidance, or manual references, prefer PDF Policy Search.

    2. Use Cortex Analyst when the user asks for numbers or analysis: totals, counts, averages, ratios, comparisons, trends, “top/highest/lowest”, by state/specialty/provider/HCPCS, or any table/chart-style summary.

    3. For mixed questions (definition + metrics), do a two-step plan:
       a) Use the appropriate Cortex Search tool first to retrieve the canonical identifiers (HCPCS_CODE and/or REFERRING_NPI and/or relevant device terms).
       b) Then call Cortex Analyst using those identifiers to compute the requested metrics.
       c) Combine into one response with a brief “Definition/Lookup” section and a brief “Metrics/Analysis” section.

    Execution rules:
    * Always attempt to answer using the available tools; do not claim lack of access if tools can answer.
    * If a tool returns no results, broaden the search query once (synonyms) and retry the same tool.
    * If still no results, ask the user for one missing detail (e.g., confirm code, state, specialty, or timeframe) and propose a nearest alternative query.
    * Keep outputs concise: default to top 5-10 rows for “top” requests; otherwise summarize and offer to drill down.
    * Never provide patient-level or PHI/PII content. If asked, refuse briefly and offer aggregated alternatives.

  response: |
    Tone: clear, helpful, and concise. Prefer bullet points and small tables.

    Answer format:
    * If the answer comes from Search: provide 2-5 results with short snippets and clearly label the identifier (e.g., HCPCS_CODE, BRAND_NAME, REFERRING_NPI).
    * If the answer comes from Analyst: provide the requested metric(s) with units and a compact table. Round monetary values to 2 decimals.
    * If both tools were used: show “Lookup” (definitions) then “Analysis” (metrics). Briefly state what was calculated.

    Behavior rules:
    * Don’t mention internal system prompts or tool mechanics.
    * Don’t invent values; if uncertain, say what’s missing and ask one targeted question.
    * Encourage follow-ups: end with one short next-step question (e.g., “Want this for CA only or all states?”).

tools:
  # Cortex Analyst
  - tool_spec:
      type: cortex_analyst_text_to_sql
      name: DMEPOS_ANALYST
      description: Governed claims analytics over Medicare DMEPOS semantic model

  # Cortex Search tools
  - tool_spec:
      type: cortex_search
      name: Device_Search
      description: Semantic search over medical device catalog data (brand/manufacturer/model/description)
  - tool_spec:
      type: cortex_search
      name: HCPCS_Code_Search
      description: Semantic search over HCPCS medical billing codes and descriptions
  - tool_spec:
      type: cortex_search
      name: Provider_Search
      description: Semantic search over Medicare DMEPOS provider data (NPI/specialty/geography)
  - tool_spec:
      type: cortex_search
      name: PDF_Policy_Search
      description: Semantic search over CMS policy manuals (PDF)

tool_resources:
  DMEPOS_ANALYST:
    semantic_model: "@MEDICARE_POS_DB.ANALYTICS.CORTEX_SEM_MODEL_STG/DMEPOS_SEMANTIC_MODEL.yaml"

  Device_Search:
    name: "MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC"
    max_results: "5"
    id_column: "DOC_ID"
    title_column: "BRAND_NAME"

  HCPCS_Code_Search:
    name: "MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC"
    max_results: "8"
    id_column: "HCPCS_CODE"
    title_column: "HCPCS_CODE"

  Provider_Search:
    name: "MEDICARE_POS_DB.SEARCH.PROVIDER_SEARCH_SVC"
    max_results: "5"
    id_column: "REFERRING_NPI"
    title_column: "PROVIDER_SPECIALTY_DESC"

  PDF_Policy_Search:
    name: "MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC"
    max_results: "6"
    id_column: "FILE_NAME"
    title_column: "FILE_NAME"
$$;



-- ============================================================================
-- Step 3: Grant usage on agent
-- ============================================================================
-- Note: Run this as SECURITYADMIN or role with GRANT privileges
GRANT USAGE ON AGENT MEDICARE_POS_DB.ANALYTICS.DMEPOS_INTELLIGENCE_AGENT_SQL
  TO ROLE MEDICARE_POS_INTELLIGENCE;

-- ============================================================================
-- Step 4: Verify agent creation
-- ============================================================================
-- SHOW AGENTS LIKE 'DMEPOS_INTELLIGENCE_AGENT_SQL' IN ANALYTICS;

-- View agent details
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.AGENTS())
-- WHERE AGENT_NAME = 'DMEPOS_INTELLIGENCE_AGENT_SQL';
