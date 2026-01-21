-- Cortex Search service for provider directory entries.

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema ANALYTICS;

-- 1) Build the provider search corpus
create or replace table ANALYTICS.PROVIDER_SEARCH_DOCS as
select
  referring_npi as doc_id,
  'provider_profile' as doc_type,
  concat(
    coalesce(provider_first_name, ''), ' ',
    coalesce(provider_last_name, ''), ' - ',
    coalesce(provider_specialty_desc, 'Unknown Specialty')
  ) as title,
  concat(
    'Provider: ', coalesce(provider_first_name, ''), ' ', coalesce(provider_last_name, ''), '. ',
    'NPI: ', referring_npi, '. ',
    'Specialty: ', coalesce(provider_specialty_desc, 'Unknown'), '. ',
    'Location: ', coalesce(provider_city, 'Unknown'), ', ',
    coalesce(provider_state, ''), ' ', coalesce(provider_zip, ''), '. ',
    'Country: ', coalesce(provider_country, 'USA'), '. ',
    case provider_specialty_desc
      when 'Family Practice' then 'Provides comprehensive primary care for all ages.'
      when 'Internal Medicine' then 'Focuses on adult medicine and complex diagnoses.'
      when 'Orthopedic Surgery' then 'Treats musculoskeletal conditions and injuries.'
      when 'Endocrinology' then 'Specializes in hormone disorders and diabetes care.'
      when 'Physical Medicine and Rehabilitation' then 'Restores function and mobility.'
      when 'Nurse Practitioner' then 'Advanced practice clinician for primary and specialty care.'
      else concat('Specialty: ', coalesce(provider_specialty_desc, 'General Practice'))
    end
  ) as body,
  referring_npi,
  provider_first_name,
  provider_last_name,
  provider_specialty_code,
  provider_specialty_desc,
  provider_city,
  provider_state,
  provider_zip,
  provider_country
from MEDICARE_POS_DB.ANALYTICS.DIM_PROVIDER
where referring_npi is not null;

-- 2) Create the Cortex Search service
create or replace cortex search service ANALYTICS.PROVIDER_SEARCH_SVC
  on body
  attributes doc_id, doc_type, referring_npi, provider_specialty_desc, provider_city, provider_state
  warehouse = MEDICARE_POS_WH
  target_lag = '1 day'
as (
  select
    body,
    doc_id,
    doc_type,
    referring_npi,
    provider_specialty_desc,
    provider_city,
    provider_state
  from ANALYTICS.PROVIDER_SEARCH_DOCS
);

-- 3) Optional access grant
-- grant usage on cortex search service MEDICARE_POS_DB.ANALYTICS.PROVIDER_SEARCH_SVC
--   to role MEDICARE_POS_INTELLIGENCE;
