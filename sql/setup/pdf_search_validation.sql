-- ============================================================================
-- PDF Search Service Validation & Testing
-- ============================================================================
--
-- LEARN ABOUT THIS:
--   📖 PDF search patterns: medium/claude/subarticle_1_intelligence_layer.md#pdf-search
--   📚 Cortex Search API: docs/reference/cortex_search_api.md
--   📚 RAG patterns: docs/reference/rag_patterns.md
--   📚 Search quality metrics: docs/reference/search_validation.md
--   🚀 Getting started: docs/implementation/getting-started.md
--   📘 Snowflake docs: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/
--
-- ============================================================================
-- BEFORE RUNNING:
-- 1. Ensure pdf_stage_setup.sql has been executed
-- 2. Ensure cortex_search_pdf.sql has been executed and service is active
-- 3. Verify PDFs are uploaded: LIST @SEARCH.PDF_STAGE
-- 4. Confirm you have access to Cortex Complete function (account feature)
--
-- ============================================================================

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- ============================================================================
-- Step 1: Verify search service exists
-- ============================================================================

-- Check service status
show cortex search services like 'PDF_SEARCH_SVC' in SEARCH;

-- View service details
select
  name,
  database_name,
  schema_name,
  created_on,
  comment
from table(information_schema.cortex_search_services())
where name = 'PDF_SEARCH_SVC';

-- Expected: PDF_SEARCH_SVC should be listed with ACTIVE status

-- ============================================================================
-- Step 2: Basic search tests
-- ============================================================================

-- Test 1: Basic search for rental equipment
select
  file_name,
  page_number,
  left(pdf_text, 200) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH(
    'DMEPOS rental equipment billing rules',
    limit => 5
  )
);

-- Expected: 5 results from CMS Chapter 20 with rental billing context

-- ============================================================================
-- Step 3: Multi-query quality test
-- ============================================================================

-- Test multiple queries to verify search quality across different topics
select
  'Test 1: Rental rules' as test_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('rental equipment rules', limit => 3)
)

union all

select
  'Test 2: Fee schedule',
  file_name,
  page_number,
  left(pdf_text, 150)
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('Medicare fee schedule calculation', limit => 3)
)

union all

select
  'Test 3: Documentation requirements',
  file_name,
  page_number,
  left(pdf_text, 150)
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('required documentation DMEPOS', limit => 3)
);

-- Expected results:
-- Test 1: Chapter 20 sections on rental billing
-- Test 2: Chapter 23 sections on fee schedule
-- Test 3: Chapter 20 documentation requirements

-- ============================================================================
-- Step 4: RAG pattern with Cortex Complete
-- ============================================================================

-- Example 1: Retrieve policy context and generate answer
with policy_context as (
  select listagg(pdf_text, '\n\n---\n\n') as context_text
  from table(
    SEARCH.PDF_SEARCH_SVC!SEARCH(
      'rental equipment documentation requirements',
      limit => 3
    )
  )
)
select
  snowflake.cortex.complete(
    'mistral-large2',
    array_construct(
      object_construct(
        'role', 'system',
        'content', 'You are a CMS policy expert. Answer based on provided policy context.'
      ),
      object_construct(
        'role', 'user',
        'content', concat(
          'Policy Context:\n',
          context_text,
          '\n\nQuestion: What documentation is required for DMEPOS rental billing?'
        )
      )
    )
  ) as answer
from policy_context;

-- Expected: LLM-generated answer based on retrieved policy context

-- ============================================================================
-- Step 5: Hybrid pattern - Policy context + Structured metrics
-- ============================================================================

-- Combine PDF policy context with current claims metrics
with policy_context as (
  select listagg(pdf_text, '\n\n') as policy_text
  from table(
    SEARCH.PDF_SEARCH_SVC!SEARCH('DMEPOS rental rules', limit => 3)
  )
),
rental_metrics as (
  select
    count(distinct referring_npi) as providers,
    sum(total_supplier_claims) as total_claims,
    avg(avg_supplier_medicare_payment) as avg_payment
  from ANALYTICS.FACT_DMEPOS_CLAIMS
  where supplier_rental_indicator = 'Y'
)
select
  snowflake.cortex.complete(
    'mistral-large2',
    array_construct(
      object_construct('role', 'system', 'content', 'You are a Medicare policy expert.'),
      object_construct('role', 'user', 'content', concat(
        'CMS Policy:\n', p.policy_text, '\n\n',
        'Current Metrics:\n',
        '- Providers: ', m.providers, '\n',
        '- Claims: ', m.total_claims, '\n',
        '- Avg Payment: $', round(m.avg_payment, 2), '\n\n',
        'Question: What are the rental billing rules and what is typical payment?'
      ))
    )
  ) as comprehensive_answer
from policy_context p
cross join rental_metrics m;

-- Expected: LLM answer combining policy rules + current metrics

-- ============================================================================
-- Step 6: Test queries by use case
-- ============================================================================

-- Use Case 1: Policy rules
select
  'Policy Rules' as use_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('What are CMS rules for DMEPOS rentals?', limit => 3)
);

-- Use Case 2: Fee schedule
select
  'Fee Schedule' as use_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('How is the Medicare fee schedule calculated?', limit => 3)
);

-- Use Case 3: Documentation requirements
select
  'Documentation' as use_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('What documentation is required for DME claims?', limit => 3)
);

-- Use Case 4: Pricing exceptions
select
  'Pricing Exceptions' as use_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('What are pricing exceptions for DMEPOS?', limit => 3)
);

-- Use Case 5: Billing codes
select
  'Billing Codes' as use_case,
  file_name,
  page_number,
  left(pdf_text, 150) as preview
from table(
  SEARCH.PDF_SEARCH_SVC!SEARCH('How are rental vs purchase claims coded?', limit => 3)
);

-- ============================================================================
-- Step 7: Verification checklist
-- ============================================================================

-- Checklist results (run and verify):
-- [ ] PDF files uploaded to stage (LIST @SEARCH.PDF_STAGE shows 2 files)
-- [ ] Search service created (SHOW CORTEX SEARCH SERVICES shows PDF_SEARCH_SVC)
-- [ ] Basic search returns results (Test 1 query returns 5+ results)
-- [ ] Multiple topics work (Test 2-3 return relevant sections)
-- [ ] RAG pattern works (LLM generates answers based on context)
-- [ ] Hybrid pattern works (combines policy + metrics)
-- [ ] All use cases return relevant results

-- ============================================================================
-- Maintenance: Refresh when PDFs are updated
-- ============================================================================

-- CMS updates manuals quarterly. To refresh:

-- 1. Download updated PDFs (bash - run on local machine):
-- $ curl -o docs/cms_manuals/clm104c20_dmepos_v2.pdf \
--     "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"

-- 2. Upload to stage with OVERWRITE=TRUE (SnowSQL):
-- PUT file://docs/cms_manuals/clm104c20_dmepos_v2.pdf @SEARCH.PDF_STAGE OVERWRITE=TRUE;

-- 3. Cortex Search auto-refreshes based on TARGET_LAG (1 day)
--    Or force immediate refresh:
alter cortex search service SEARCH.PDF_SEARCH_SVC refresh;

-- 4. Verify new files
select file_name, last_modified
from directory(@SEARCH.PDF_STAGE)
order by last_modified desc;

-- Expected: Updated PDFs show recent last_modified timestamp

-- ============================================================================
-- Troubleshooting
-- ============================================================================

-- Issue: Search returns no results
-- Solution: Check if PDFs are uploaded and refresh service
-- list @SEARCH.PDF_STAGE;
-- alter cortex search service SEARCH.PDF_SEARCH_SVC refresh;

-- Issue: PARSE_DOCUMENT fails
-- Solution: Verify PDF is not corrupted or encrypted
-- Run: file docs/cms_manuals/clm104c20_dmepos.pdf (on local machine)
-- Expected: "PDF document, version 1.x"

-- Issue: Poor search quality
-- Solution: Try more specific queries or increase LIMIT
-- Example: 'rental equipment billing' instead of 'rental'
-- Increase LIMIT from 3 to 10

-- ============================================================================
-- Cleanup (Only if removing PDF search)
-- ============================================================================
-- WARNING: This will delete the search service and stage

-- drop cortex search service if exists SEARCH.PDF_SEARCH_SVC;
-- drop stage if exists SEARCH.PDF_STAGE;

-- ============================================================================
-- Summary
-- ============================================================================
-- If all tests pass:
-- ✅ PDF search is ready for production
-- ✅ Can be integrated into Snowflake Intelligence UI
-- ✅ Agent can use PDF_SEARCH_SVC for policy questions
-- ============================================================================
