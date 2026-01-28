-- PDF Stage setup for CMS policy documents.
-- Run this BEFORE creating the PDF search service.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- ============================================================================
-- Step 1: Create stage for PDF files
-- ============================================================================
create stage if not exists SEARCH.PDF_STAGE
  directory = (enable = true)
  encryption = (type = 'SNOWFLAKE_SSE')
  comment = 'CMS policy documents for RAG';

-- Verify stage created
show stages like 'PDF_STAGE' in SEARCH;

-- ============================================================================
-- Step 2: Download CMS Policy PDFs (Local Machine)
-- ============================================================================
-- Run these commands on your local machine:
--
-- $ mkdir -p pdf/cms_manuals
--
-- $ curl -o pdf/cms_manuals/clm104c20_dmepos.pdf \
--     "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c20.pdf"
--
-- $ curl -o pdf/cms_manuals/clm104c23_fee_schedule.pdf \
--     "https://www.cms.gov/Regulations-and-Guidance/Guidance/Manuals/downloads/clm104c23.pdf"
--
-- ============================================================================

-- ============================================================================
-- Step 3: Upload PDFs to Snowflake Stage
-- ============================================================================

-- Option A: Using Snow CLI (Recommended)
-- $ snow sql -c sf_int -d MEDICARE_POS_DB -s SEARCH
-- > PUT 'file:///Users/sahilbhange/Desktop/DE Work/projects/snowflake-intelligence-medicare-pos-analyst/pdf/cms_manuals/*.pdf' @SEARCH.PDF_STAGE AUTO_COMPRESS=FALSE;

-- Option B: Using Snowsight UI
-- 1. Navigate to: Data > Databases > MEDICARE_POS_DB > SEARCH > Stages > PDF_STAGE
-- 2. Click "Upload Files"
-- 3. Select both PDF files
-- 4. Click "Upload"

-- ============================================================================
-- Step 4: Verify uploaded files
-- ============================================================================
list @SEARCH.PDF_STAGE;

-- Expected output:
-- clm104c20_dmepos.pdf          ~5-7 MB
-- clm104c23_fee_schedule.pdf    ~4-6 MB

-- ============================================================================
-- Step 5: Test PARSE_DOCUMENT function (Optional)
-- ============================================================================
-- Verify PDF parsing works before creating search service

select
  relative_path,
  snowflake.cortex.parse_document(
    @SEARCH.PDF_STAGE,
    relative_path,
    {'mode': 'LAYOUT'}
  ):content::string as extracted_text
from directory(@SEARCH.PDF_STAGE) -- Use directory table function for file metadata
where relative_path like '%.pdf'
limit 1;

-- Expected: Should return extracted text from first PDF

-- ============================================================================
-- Next Steps
-- ============================================================================
-- After uploading PDFs:
-- 1. Run: sql/search/cortex_search_pdf.sql to create the search service
-- 2. Run: sql/setup/pdf_search_validation.sql to test and validate
-- ============================================================================
