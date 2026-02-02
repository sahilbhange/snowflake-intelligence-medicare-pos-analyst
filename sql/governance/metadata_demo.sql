-- ============================================================================
-- Demo Governance: Minimal Column Catalog + Sensitivity Policy
-- ============================================================================
--
-- Use cases (Medium demo):
-- - "What can I safely show/share?" → query `GOVERNANCE.SENSITIVITY_POLICY`
-- - "What does this column mean?"  → query `GOVERNANCE.COLUMN_METADATA`
-- - Create a simple governance artifact that is easy to screenshot and narrate.
--
-- Why this script exists:
-- - The full governance script (`sql/governance/metadata_and_quality.sql`) is great for a
--   production-ish template, but it’s too much surface area for a hands-on tutorial.
-- - This script keeps only the pieces that add immediate value during a demo.
--
-- Upgrade path:
-- - When you want lineage, quality checks, and agent hints, switch to:
--   `make metadata` (or run `sql/governance/metadata_and_quality.sql`).
--
-- Handy demo queries (copy/paste into Snowsight):
--   -- 1) Show handling guidance by sensitivity label
--   select * from GOVERNANCE.SENSITIVITY_POLICY order by table_name, column_name;
--   -- 2) Show "confidential" fields that should be aggregated before sharing
--   select * from GOVERNANCE.COLUMN_METADATA where sensitivity = 'confidential';
--
-- ============================================================================

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- Column-level metadata: the most useful governance artifact for a demo.
create or replace table GOVERNANCE.COLUMN_METADATA (
  dataset_name string,
  column_name string,
  data_type string,
  business_definition string,
  allowed_values string,
  sensitivity string,
  example_value string,
  created_at timestamp_ntz default current_timestamp(),
  updated_at timestamp_ntz default current_timestamp()
);

-- Seed a handful of "talking points" columns (keep it small for the demo).
insert into GOVERNANCE.COLUMN_METADATA (
  dataset_name, column_name, data_type, business_definition, allowed_values, sensitivity, example_value
) values
  -- Provider identifiers (treat as internal in this demo)
  ('DIM_PROVIDER', 'referring_npi', 'number', 'National Provider Identifier for the referring provider.', '10-digit numeric', 'internal', '1003000126'),
  ('DIM_PROVIDER', 'provider_name', 'string', 'Display name for the referring provider.', 'text', 'internal', 'Jane Smith MD'),

  -- Geo attributes (safe to group by in screenshots)
  ('DIM_PROVIDER', 'provider_state', 'string', 'Two-letter US state code for provider location.', 'US state codes', 'public', 'CA'),
  ('DIM_PROVIDER', 'provider_city', 'string', 'Provider city.', 'text', 'public', 'LOS ANGELES'),

  -- Claims identifiers and measures
  ('FACT_DMEPOS_CLAIMS', 'hcpcs_code', 'string', 'HCPCS code at provider + HCPCS grain.', 'A*, E*, L*', 'public', 'E1390'),
  ('FACT_DMEPOS_CLAIMS', 'total_supplier_claims', 'number', 'Total claim count for the provider + HCPCS combination.', '>= 0', 'public', '150'),
  ('FACT_DMEPOS_CLAIMS', 'avg_supplier_medicare_payment', 'number', 'Average Medicare payment amount (USD).', '>= 0', 'confidential', '68.20');

-- Turn sensitivity labels into simple handling guidance (great for demo narration).
create or replace view GOVERNANCE.SENSITIVITY_POLICY as
select
  dataset_name as table_name,
  column_name,
  sensitivity as sensitivity_level,
  case sensitivity
    when 'public' then 'Safe to share externally'
    when 'internal' then 'Internal use only'
    when 'confidential' then 'Aggregate before sharing'
    when 'restricted' then 'Explicit approval required'
  end as handling_instructions,
  business_definition
from GOVERNANCE.COLUMN_METADATA
where sensitivity is not null;

-- Quick verification query (optional).
select 'COLUMN_METADATA' as table_name, count(*) as row_cnt from GOVERNANCE.COLUMN_METADATA
union all
select 'SENSITIVITY_POLICY', count(*) from GOVERNANCE.SENSITIVITY_POLICY;
