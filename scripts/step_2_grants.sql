-- Optional grants for demo roles after objects exist.

use role SECURITYADMIN;

grant usage on database MEDICARE_POS_DB to role MEDICARE_POS_INTELLIGENCE;
grant usage on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

grant select on table MEDICARE_POS_DB.ANALYTICS.FACT_DMEPOS_CLAIMS to role MEDICARE_POS_INTELLIGENCE;
grant select on table MEDICARE_POS_DB.ANALYTICS.DIM_PROVIDER to role MEDICARE_POS_INTELLIGENCE;

-- Enable only if available in your account.
-- grant create semantic view on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
-- grant create agent on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
