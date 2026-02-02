-- ============================================================================
-- Demo Governance: Lightweight Profiling (One Run)
-- ============================================================================
--
-- Use cases (Medium demo):
-- - "Did the data load correctly?" → row counts for key tables
-- - "Are key join columns populated?" → null rates for identifiers
-- - A quick "trust signal" section you can include in the article with screenshots.
--
-- Why this script exists:
-- - The full profiling script (`sql/governance/run_profiling.sql`) covers more metrics,
--   but it’s longer than needed for a tutorial. This keeps it fast and readable.
--
-- Where results go:
-- - `GOVERNANCE.DATA_PROFILE_RESULTS` (append-only). Each run has a new `run_id`.
--
-- Scheduling note:
-- - For the Medium demo, you run this manually (via `make profile-demo`).
-- - In production, you’d wrap this in a Snowflake TASK and alert on thresholds.
--
-- Handy demo queries:
--   -- Latest profiling run (most recent metrics)
--   select *
--   from GOVERNANCE.DATA_PROFILE_RESULTS
--   qualify run_ts = max(run_ts) over ()
--   order by dataset_name, metric_name, column_name;
--
-- ============================================================================

use role MEDICARE_POS_INTELLIGENCE;
use database MEDICARE_POS_DB;
use schema GOVERNANCE;

-- Results table is append-only so repeated runs are easy to compare.
create table if not exists GOVERNANCE.DATA_PROFILE_RESULTS (
  run_id string,
  run_ts timestamp_ntz default current_timestamp(),
  dataset_name string,
  column_name string,
  metric_name string,
  metric_value number(38,6),
  notes string
);

set run_id = uuid_string();

-- ---------------------------------------------------------------------------
-- Row counts (demo: curated + analytics only)
-- ---------------------------------------------------------------------------
insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'CURATED.DMEPOS_CLAIMS', null, 'row_count', count(*), 'Curated claims rows'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'CURATED.GUDID_DEVICES', null, 'row_count', count(*), 'Curated device rows'
from CURATED.GUDID_DEVICES;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'ANALYTICS.DIM_PROVIDER', null, 'row_count', count(*), 'Provider dimension rows'
from ANALYTICS.DIM_PROVIDER;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select $run_id, current_timestamp(), 'ANALYTICS.FACT_DMEPOS_CLAIMS', null, 'row_count', count(*), 'Fact rows'
from ANALYTICS.FACT_DMEPOS_CLAIMS;

-- ---------------------------------------------------------------------------
-- Null rates (demo: a few key columns)
-- ---------------------------------------------------------------------------
insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'CURATED.DMEPOS_CLAIMS',
  'hcpcs_code',
  'null_rate',
  round(count_if(hcpcs_code is null) / nullif(count(*), 0), 6),
  'Expect near zero'
from CURATED.DMEPOS_CLAIMS;

insert into GOVERNANCE.DATA_PROFILE_RESULTS (run_id, run_ts, dataset_name, column_name, metric_name, metric_value, notes)
select
  $run_id,
  current_timestamp(),
  'ANALYTICS.DIM_PROVIDER',
  'provider_state',
  'null_rate',
  round(count_if(provider_state is null) / nullif(count(*), 0), 6),
  'Some nulls expected'
from ANALYTICS.DIM_PROVIDER;

-- Quick readout for the current run (handy in a worksheet / Medium screenshot).
select *
from GOVERNANCE.DATA_PROFILE_RESULTS
where run_id = $run_id
order by dataset_name, metric_name, column_name;
