-- Project bootstrap: role, warehouse, database, schema, user defaults.
-- Update target_user if you want to bind a different Snowflake user.

set target_user = 'YOUR_USER';

-- 1) Create role (SECURITYADMIN)
use role SECURITYADMIN;
create role if not exists MEDICARE_POS_INTELLIGENCE;

grant role MEDICARE_POS_INTELLIGENCE to role SYSADMIN;

-- 2) Create warehouse, database, schema (SYSADMIN)
use role SYSADMIN;

create warehouse if not exists MEDICARE_POS_WH
  with warehouse_size = 'XSMALL'
  auto_suspend = 300
  auto_resume = true
  initially_suspended = true;

create database if not exists MEDICARE_POS_DB
  comment = 'Medicare POS analytics demo database';

create schema if not exists MEDICARE_POS_DB.ANALYTICS
  comment = 'Core analytics schema for the demo';

-- 3) Grant baseline access (SECURITYADMIN)
use role SECURITYADMIN;

grant usage on database MEDICARE_POS_DB to role MEDICARE_POS_INTELLIGENCE;
grant usage on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

grant select on all tables in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on future tables in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

grant select on all views in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;
grant select on future views in schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

grant create table, create view, create file format, create stage, create cortex search service
  on schema MEDICARE_POS_DB.ANALYTICS to role MEDICARE_POS_INTELLIGENCE;

grant usage, operate on warehouse MEDICARE_POS_WH to role MEDICARE_POS_INTELLIGENCE;

-- 4) Bind user defaults (SECURITYADMIN)
-- Make sure target_user is set to an existing user.

alter user identifier($target_user)
  set default_role = MEDICARE_POS_INTELLIGENCE,
      default_warehouse = MEDICARE_POS_WH,
      default_namespace = MEDICARE_POS_DB.ANALYTICS;

grant role MEDICARE_POS_INTELLIGENCE to user identifier($target_user);
