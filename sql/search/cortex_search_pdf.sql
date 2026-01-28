-- ============================================================================
-- Cortex Search Service for CMS Policy PDF Documents
-- ============================================================================
--
-- LEARN ABOUT THIS:
--   📖 PDF search concepts: medium/claude/subarticle_1_intelligence_layer.md#pdf-search
--   📚 Reference guide: docs/reference/embedding_strategy.md#pdf-search-with-cortex-search
--   📚 PDF sources: docs/reference/pdf_sources.md
--   🚀 Getting started: docs/implementation/getting-started.md
--
-- ============================================================================
-- BEFORE RUNNING:
-- 1. Upload PDFs to @SEARCH.PDF_STAGE (run sql/setup/pdf_stage_setup.sql first)
-- 2. Verify PDFs uploaded: LIST @SEARCH.PDF_STAGE
-- 3. Test search after creation: sql/setup/pdf_search_validation.sql
--
-- ============================================================================

-- Cortex Search service for CMS Policy PDF documents.
-- Reference: https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/tutorials/cortex-search-tutorial-3-chat-advanced
--
-- Prerequisites:
-- 1. Run sql/setup/pdf_stage_setup.sql to create stage and upload PDFs
-- 2. Verify PDFs uploaded: LIST @SEARCH.PDF_STAGE;
--
-- Post-deployment:
-- Run sql/setup/pdf_search_validation.sql to test and validate

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- Check if PDF docs uploaded
list @SEARCH.PDF_STAGE;

-- Build a raw text table from staged PDFs (layout-preserving extraction).
create or replace table SEARCH.PDF_RAW_TEXT as
select
  relative_path as file_name,
  to_varchar(
    snowflake.cortex.parse_document(
      @SEARCH.PDF_STAGE,
      relative_path,
      {'mode': 'LAYOUT'}  -- Preserves layout for better context
    ):content
  ) as extracted_layout,
  last_modified
from directory(@SEARCH.PDF_STAGE) -- Directory table function for file metadata
where relative_path like '%.pdf';

-- select * from SEARCH.PDF_RAW_TEXT limit 100;

-- Build a chunked corpus table for search using Markdown header-aware splitting.
-- Requires SNOWFLAKE.CORTEX.SPLIT_TEXT_MARKDOWN_HEADER privileges.
create or replace table SEARCH.PDF_CHUNKS as
select
  r.file_name,
  c.index as page_number, -- Chunk index when header-based split is used
  (
    r.file_name || ':\n'
    || coalesce('Header 1: ' || c.value:headers:header_1::string || '\n', '')
    || coalesce('Header 2: ' || c.value:headers:header_2::string || '\n', '')
    || c.value:chunk::string
  ) as pdf_text,
  r.last_modified
from SEARCH.PDF_RAW_TEXT r,
  lateral flatten(
    input => snowflake.cortex.split_text_markdown_header(
      r.extracted_layout,
      object_construct('#', 'header_1', '##', 'header_2'),
      2000, -- Chunk size in characters
      300   -- Overlap in characters
    )
  ) c
where r.extracted_layout is not null
  and c.value:chunk is not null
  and length(c.value:chunk::string) > 0;

-- Create Cortex Search service with automatic PDF parsing
create or replace cortex search service SEARCH.PDF_SEARCH_SVC
  on pdf_text
  attributes file_name, page_number, last_modified
  warehouse = MEDICARE_POS_WH
  target_lag = '1 day'
  comment = 'CMS policy manual search with automatic PDF parsing and hybrid search'
as (
  select
    pdf_text,
    file_name,
    page_number,
    last_modified
  from SEARCH.PDF_CHUNKS
);

-- Optional access grant
-- grant usage on cortex search service MEDICARE_POS_DB.SEARCH.PDF_SEARCH_SVC
--   to role MEDICARE_POS_INTELLIGENCE;
