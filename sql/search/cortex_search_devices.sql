-- ============================================================================
-- Cortex Search Service for Medical Device Catalog (FDA GUDID)
-- ============================================================================
--
-- LEARN ABOUT THIS:
--   📖 Search concepts: medium/claude/subarticle_1_intelligence_layer.md#search-services
--   📚 Reference guide: docs/reference/embedding_strategy.md
--   📚 FDA GUDID data: docs/reference/device_catalog.md
--   📚 Agent integration: docs/reference/cortex_agent_creation.md
--   🚀 Getting started: docs/implementation/getting-started.md
--
-- ============================================================================
-- BEFORE RUNNING:
-- 1. Ensure CURATED.GUDID_DEVICES is created (run: make model)
-- 2. Verify device data exists: SELECT COUNT(*) FROM CURATED.GUDID_DEVICES;
-- 3. After creation, validate in Snowflake UI: SEARCH > DEVICE_SEARCH_SVC > Playground > Search('Wheelchair')
--
-- ============================================================================

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema SEARCH;

-- 1) Build the device search corpus
create or replace table SEARCH.DEVICE_SEARCH_DOCS as
select
  public_device_record_key as doc_id,
  'medical_device' as doc_type,
  coalesce(device_description, brand_name, 'Unknown Device') as title,
  concat(
    'Device: ', coalesce(device_description, brand_name, 'Unknown'), '. ',
    'Brand: ', coalesce(brand_name, 'N/A'), '. ',
    'Company: ', coalesce(company_name, 'N/A'), '. ',
    'Model: ', coalesce(version_or_model_number, 'N/A'), '. ',
    'Catalog: ', coalesce(catalog_number, 'N/A'), '. ',
    case
      when device_description is not null then concat('Description: ', device_description, '. ')
      else ''
    end
  ) as body,
  di_number,
  brand_name,
  company_name,
  version_or_model_number,
  catalog_number,
  device_description
from CURATED.GUDID_DEVICES
where (device_description is not null or brand_name is not null)
  and company_name is not null
  and (
    company_name in (
      'Cardinal Health 200, LLC',
      'MEDLINE INDUSTRIES, INC.',
      'ICU MEDICAL, INC.',
      'Bauerfeind AG',
      'Smith & Nephew, Inc.'
    )
    or device_description ilike '%wheelchair%'
    or device_description ilike '%walker%'
    or device_description ilike '%oxygen%'
    or device_description ilike '%diabetic%'
    or device_description ilike '%prosthetic%'
    or device_description ilike '%orthotic%'
  );

-- 2) Create the Cortex Search service
create or replace cortex search service SEARCH.DEVICE_SEARCH_SVC
  on body
  attributes doc_id, doc_type, di_number, brand_name, company_name
  warehouse = MEDICARE_POS_WH
  target_lag = '7 day'
as (
  select
    body,
    doc_id,
    doc_type,
    di_number,
    brand_name,
    company_name
  from SEARCH.DEVICE_SEARCH_DOCS
);

-- 3) Optional access grant
-- grant usage on cortex search service MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC
--   to role MEDICARE_POS_INTELLIGENCE;
