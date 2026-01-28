# The Foundation Layer: Building Data Architecture for AI Workloads

*Or: Why Your Data Warehouse Needs a Midlife Crisis*

---

**Part of the series:** [The Complete Guide to Snowflake Intelligence](#) (Hub Article)

**Navigation:**
- 🧠 [Part 1: The Intelligence Layer](subarticle_1_intelligence_layer.md) - How AI understands your data
- 🏗️ **Part 2: The Foundation Layer** (You are here)
- 🛡️ [Part 3: The Trust Layer](subarticle_3_trust_layer.md) - Governance and production readiness

**Quick Links:**
| Want This | See This |
|-----------|----------|
| Quick reference on data model | [Docs: Data Model](../docs/implementation/data_model.md) |
| Deployment steps | [Docs: Getting Started](../docs/implementation/getting-started.md) |
| Working SQL code | [SQL: Data Loading](../sql/ingestion/load_raw_data.sql) |

---

## The $500,000 Mistake

Sarah was excited. Her company just got Snowflake Intelligence, and she was going to be a hero.

**Day 1:** She pointed Cortex Analyst at their existing data warehouse and created a semantic model.

**Day 2:** She demoed it to the executive team. Questions were answered in seconds. Jaws dropped. She got a standing ovation.

**Day 3:** The CFO started using it. A lot. Every question was a 45-second query. At $3 per query.

**Day 30:** Snowflake bill arrived. **$94,000.**

(Previous month: $18,000.)

Sarah was no longer a hero.

**What went wrong?**

Sarah's semantic model was pointing at raw JSON tables. Every query required:
1. Parsing nested JSON (expensive)
2. Full table scans (no clustering)
3. String matching on unparsed fields (very expensive)
4. Joining raw tables without proper keys (extremely expensive)

**The fix:** Refactor to a curated star schema. Same queries, 2 seconds instead of 45 seconds, $0.12 instead of $3.

**Time to refactor:** 3 weeks.

**Savings:** $500,000+ per year.

This is why the Foundation Layer matters.

---

## The Inconvenient Truth

Your data warehouse was built for humans. Specifically, for data engineers and analysts who:
- Know which tables to join
- Understand your business logic
- Write SQL all day
- Don't mind waiting 30 seconds for results
- Care about getting the exact data they need

**AI is different. AI needs:**
- Self-describing tables (metadata everywhere)
- Predictable structure (star schemas > snowflakes > raw tables)
- Fast queries (materialized > computed)
- Clear separation (RAW ≠ ANALYTICS ≠ SEARCH)
- Governance baked in (what can AI query?)

**If you try to run Snowflake Intelligence on a data warehouse designed for humans, you'll end up like Sarah.**

This article is about building (or refactoring) your data platform for AI workloads.

---

## What You'll Learn

By the end of this deep dive, you'll know:

1. **Medallion Architecture** - Why RAW → CURATED → ANALYTICS matters for AI
2. **Schema Organization** - How to separate concerns (6 schemas, not 1)
3. **Data Modeling** - Star schemas that AI loves
4. **Data Loading** - Ingestion patterns for JSON, delimited files, and APIs
5. **Storage Optimization** - Making queries fast and cheap
6. **Automation** - One-command deployment with Make
7. **Real Implementation** - Medicare demo project walkthrough

**Estimated reading time:** 20-25 minutes

**Code repository:** [GitHub - Snowflake Intelligence Medicare Demo](#)

Let's build.

---

## Part 1: Medallion Architecture for AI

### What Is Medallion Architecture?

It's a three-layer pattern for data lakes and warehouses:

1. **RAW (Bronze)** - Files as-is, no transformations
2. **CURATED (Silver)** - Cleaned, typed, deduplicated
3. **ANALYTICS (Gold)** - Business-ready, modeled (facts + dimensions)

**Analogy:** Think of it like cooking.
- **RAW:** Ingredients fresh from the market (carrots still have dirt)
- **CURATED:** Prepped ingredients (washed, chopped, measured)
- **ANALYTICS:** The finished dish (ready to serve)

You wouldn't serve raw ingredients to guests. Don't serve raw data to AI.

---

### Why Medallion Matters for AI

**Scenario:** Your VP asks Cortex Analyst, "What's the average reimbursement by state?"

**With medallion:**
```
Cortex → ANALYTICS.FACT_CLAIMS (curated star schema)
       → Clean, indexed, clustered
       → Query: 2 seconds, $0.10
```

**Without medallion:**
```
Cortex → RAW.JSON_FILES (nested, unparsed)
       → Parse JSON, filter nulls, deduplicate, aggregate
       → Query: 47 seconds, $3.20
```

**The math:**
- 100 queries/day × $3.20 = $320/day = $116,800/year
- vs
- 100 queries/day × $0.10 = $10/day = $3,650/year

**Savings:** $113,150/year. For one use case.

---

### The Three Layers in Detail

#### Layer 1: RAW (Bronze)

**Purpose:** Store files exactly as received, no transformations.

**Schema:** `MEDICARE_POS_DB.RAW`

**Tables:**
```sql
-- CMS DMEPOS claims (JSON)
RAW.RAW_DMEPOS

-- FDA device catalog (delimited files)
RAW.RAW_GUDID_DEVICE
RAW.RAW_GUDID_PRODUCT_CODES
```

**Key principles:**
- ✅ **Immutable** - Never modify raw data
- ✅ **Auditable** - Keep load timestamps
- ✅ **Replayable** - Can rebuild downstream layers
- ✅ **Cheap** - Store in internal stages, compress

**When to query RAW:**
- Debugging data quality issues
- Reprocessing after logic changes
- Forensic analysis ("what did we load on June 3rd?")

**When NOT to query RAW:**
- Production analytics (use CURATED/ANALYTICS)
- Cortex Analyst (pointing at RAW is a crime)
- Ad-hoc user queries (they'll create expensive queries)

---

#### Layer 2: CURATED (Silver)

**Purpose:** Clean, typed, deduplicated data ready for modeling.

**Schema:** `MEDICARE_POS_DB.CURATED`

**Tables:**
```sql
CURATED.DMEPOS_CLAIMS    -- Claims with typed columns
CURATED.GUDID_DEVICES    -- Device catalog (normalized)
```

**Transformations applied:**
```sql
-- Example: RAW → CURATED
CREATE OR REPLACE TABLE CURATED.DMEPOS_CLAIMS AS
SELECT
  -- Extract from JSON and cast to proper types
  $1:Rndrng_Prvdr_NPI::STRING AS provider_npi,
  $1:Rndrng_Prvdr_Last_Org_Name::STRING AS provider_name,
  $1:Rndrng_Prvdr_State_Abrvtn::STRING AS provider_state,
  $1:HCPCS_Cd::STRING AS hcpcs_code,
  $1:Tot_Benes::INT AS total_beneficiaries,
  $1:Tot_Srvcs::INT AS total_services,
  $1:Avg_Allowed_Amt::FLOAT AS avg_allowed_amount,

  -- Add audit columns
  CURRENT_TIMESTAMP AS loaded_at,

  -- Deduplicate
  ROW_NUMBER() OVER (
    PARTITION BY provider_npi, hcpcs_code
    ORDER BY loaded_at DESC
  ) AS row_rank
FROM RAW.RAW_DMEPOS
QUALIFY row_rank = 1;  -- Keep only latest version
```

**Key principles:**
- ✅ **Typed** - No more `$1:field::string`, use actual columns
- ✅ **Deduplicated** - One version of truth per entity
- ✅ **Auditable** - Add `loaded_at`, `updated_at`
- ✅ **Validated** - Check for nulls, outliers, duplicates

**When to query CURATED:**
- Data exploration
- Building new analytics models
- Data quality checks

**When NOT to query CURATED:**
- Cortex Analyst (use ANALYTICS instead)
- Complex multi-table joins (use ANALYTICS star schema)

---

#### Layer 3: ANALYTICS (Gold)

**Purpose:** Business-ready data modeled as facts and dimensions.

**Schema:** `MEDICARE_POS_DB.ANALYTICS`

**Tables:**
```sql
-- Dimensions
ANALYTICS.DIM_PROVIDER         -- Provider info (NPI, name, specialty, location)
ANALYTICS.DIM_DEVICE           -- Device catalog (brand, manufacturer, description)
ANALYTICS.DIM_PRODUCT_CODE     -- HCPCS product codes and descriptions
ANALYTICS.DIM_DATE             -- Date dimension (year, quarter, month, day)

-- Facts
ANALYTICS.FACT_DMEPOS_CLAIMS   -- Claims fact (grain: provider × HCPCS × year)
```

**Star schema example:**
```sql
-- Fact table
CREATE OR REPLACE VIEW ANALYTICS.FACT_DMEPOS_CLAIMS AS
SELECT
  provider_npi,                  -- FK to DIM_PROVIDER
  hcpcs_code,                    -- FK to DIM_DEVICE (via HCPCS)
  EXTRACT(YEAR FROM service_date) AS year,

  -- Measures
  SUM(total_beneficiaries) AS total_beneficiaries,
  SUM(total_services) AS total_services,
  AVG(avg_allowed_amount) AS avg_allowed_amount,
  SUM(total_services * avg_allowed_amount) AS total_allowed_amount
FROM CURATED.DMEPOS_CLAIMS
GROUP BY provider_npi, hcpcs_code, year;

-- Dimension: Provider
CREATE OR REPLACE VIEW ANALYTICS.DIM_PROVIDER AS
SELECT DISTINCT
  provider_npi,
  provider_name,
  provider_specialty,
  provider_state,
  provider_city,
  provider_zip
FROM CURATED.DMEPOS_CLAIMS;
```

**Key principles:**
- ✅ **Star schema** - Facts + dimensions (AI loves this)
- ✅ **Grain clarity** - One row = one what?
- ✅ **Descriptive names** - `total_allowed_amount` not `amt`
- ✅ **Denormalized** - Joins already done

**When to query ANALYTICS:**
- Cortex Analyst semantic models (THIS IS THE LAYER)
- User dashboards
- Business reports

**This is where AI should live.**

---

### Medallion: The Complete Flow

```
┌──────────────────────────────────────────────┐
│  DATA SOURCES                                │
│  ┌────────────┐  ┌─────────────────────────┐│
│  │ CMS API    │  │ FDA GUDID ZIP           ││
│  │ (JSON)     │  │ (Delimited files)       ││
│  └────────────┘  └─────────────────────────┘│
└──────────────────────────────────────────────┘
           │                    │
           ▼                    ▼
┌──────────────────────────────────────────────┐
│  RAW (Bronze)                                │
│  ┌──────────────┐  ┌─────────────────────┐  │
│  │ RAW_DMEPOS   │  │ RAW_GUDID_DEVICE    │  │
│  │ (Variant)    │  │ (String columns)    │  │
│  └──────────────┘  └─────────────────────┘  │
│  Immutable, compressed, auditable            │
└──────────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────┐
│  CURATED (Silver)                            │
│  ┌──────────────────┐  ┌──────────────────┐ │
│  │ DMEPOS_CLAIMS    │  │ GUDID_DEVICES    │ │
│  │ (Typed columns)  │  │ (Normalized)     │ │
│  └──────────────────┘  └──────────────────┘ │
│  Deduplicated, validated, typed              │
└──────────────────────────────────────────────┘
                       ▼
┌──────────────────────────────────────────────┐
│  ANALYTICS (Gold)                            │
│  ┌────────────┐  ┌──────────┐  ┌──────────┐ │
│  │DIM_PROVIDER│  │DIM_DEVICE│  │DIM_PRODUCT│ │
│  └────────────┘  └──────────┘  └──────────┘ │
│         ┌───────────────────────┐            │
│         │ FACT_DMEPOS_CLAIMS    │            │
│         └───────────────────────┘            │
│  Star schema, business-ready                 │
└──────────────────────────────────────────────┘
```

**[DIAGRAM PLACEHOLDER: medallion_flow.png]**

---

## Part 2: Schema Organization (The 6-Schema Pattern)

### The Problem with One Schema

Most data warehouses have one or two schemas:
```
DATABASE.PUBLIC     -- Everything lives here
DATABASE.STAGING    -- ETL scratch space
```

**Why this fails for AI:**
- ❌ No separation of concerns (raw mixed with analytics)
- ❌ Unclear ownership (who maintains what?)
- ❌ Governance nightmare (grant SELECT on PUBLIC? Everything?)
- ❌ Search services mixed with tables
- ❌ Logging/instrumentation has nowhere to go

---

### The 6-Schema Pattern

```
MEDICARE_POS_DB
├── RAW             -- Bronze: Immutable source data
├── CURATED         -- Silver: Cleaned, typed, deduplicated
├── ANALYTICS       -- Gold: Star schema (facts + dimensions)
├── SEARCH          -- Cortex Search services (not tables!)
├── INTELLIGENCE    -- Query logs, eval seeds, validation
└── GOVERNANCE      -- Metadata, lineage, quality checks
```

**Why this works:**

1. **RAW** - Only ETL processes write here
2. **CURATED** - Data engineers own this
3. **ANALYTICS** - Analytics engineers own this (DBT models live here)
4. **SEARCH** - Cortex Search services (HCPCS, devices, providers)
5. **INTELLIGENCE** - AI instrumentation (who queried what, when)
6. **GOVERNANCE** - Metadata catalog, quality results, lineage

---

### Schema Design Decisions

#### Why SEARCH is separate from ANALYTICS

**Cortex Search services are NOT tables.** They're... services.

```sql
-- This is NOT a table
CREATE CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC
  ON description
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT hcpcs_code, hcpcs_description AS description
  FROM ANALYTICS.DIM_HCPCS
);
```

When you query a search service:
```sql
SELECT * FROM SEARCH.HCPCS_SEARCH_SVC('oxygen concentrator');
```

You're not querying a table, you're calling a service that:
1. Indexes text
2. Optionally creates embeddings
3. Returns results ranked by similarity

**Putting search services in a separate schema:**
- ✅ Clarifies that these aren't queryable tables
- ✅ Makes grants easier (`USAGE ON CORTEX SEARCH SERVICE`)
- ✅ Logical separation (search ≠ analytics)

---

#### Why INTELLIGENCE is separate from ANALYTICS

**INTELLIGENCE schema stores AI system metadata:**
```sql
INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG     -- Every query AI answered
INTELLIGENCE.EVAL_SEED_QUESTIONS          -- Golden test questions
INTELLIGENCE.HUMAN_VALIDATION_RESULTS     -- Thumbs up/down feedback
INTELLIGENCE.SEMANTIC_MODEL_CHANGELOG     -- Model version history
```

**Why separate:**
- ✅ DML access (logs need INSERT/UPDATE, analytics tables are read-only)
- ✅ Different retention (logs = 90 days, analytics = forever)
- ✅ Security (not everyone needs to see query logs)

---

#### Why GOVERNANCE is separate

**GOVERNANCE stores data about your data:**
```sql
GOVERNANCE.COLUMN_METADATA       -- Business definitions for every column
GOVERNANCE.TABLE_LINEAGE         -- Upstream dependencies
GOVERNANCE.QUALITY_CHECKS        -- Profiling results, null rates, outliers
GOVERNANCE.SENSITIVITY_TAGS      -- PII, PHI, GDPR classifications
```

**Why separate:**
- ✅ Cross-cutting (applies to all schemas)
- ✅ Different stakeholders (data governance team)
- ✅ Compliance (auditors need access, analysts don't)

---

### Creating the Schemas

```sql
-- sql/setup/setup_user_and_roles.sql

USE ROLE ACCOUNTADMIN;

-- Create database
CREATE DATABASE IF NOT EXISTS MEDICARE_POS_DB;

-- Create medallion schemas
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.RAW;
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.CURATED;
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.ANALYTICS;

-- Create specialized schemas
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.SEARCH;
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.INTELLIGENCE;
CREATE SCHEMA IF NOT EXISTS MEDICARE_POS_DB.GOVERNANCE;
```

**[GitHub Gist: full setup script](#)**

> **🔗 Reference:** See full implementation in [sql/setup/setup_user_and_roles.sql](../sql/setup/setup_user_and_roles.sql)

---

## Part 3: Role-Based Access Control for AI

### The Two Roles Pattern

```sql
-- Role 1: Admin (data engineers)
CREATE ROLE IF NOT EXISTS MEDICARE_POS_ADMIN;

-- Role 2: Intelligence (AI + business users)
CREATE ROLE IF NOT EXISTS MEDICARE_POS_INTELLIGENCE;
```

---

### Admin Role: Full Access

```sql
-- Admin can do everything
GRANT ALL PRIVILEGES ON DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_ADMIN;
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_ADMIN;
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_ADMIN;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE MEDICARE_POS_DB TO ROLE MEDICARE_POS_ADMIN;
```

---

### Intelligence Role: Read Analytics, Use Search, Write Logs

```sql
-- ANALYTICS: Read-only
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.ANALYTICS TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT ON ALL VIEWS IN SCHEMA MEDICARE_POS_DB.ANALYTICS TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA MEDICARE_POS_DB.ANALYTICS TO ROLE MEDICARE_POS_INTELLIGENCE;

-- SEARCH: Usage on services
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.SEARCH TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT USAGE ON CORTEX SEARCH SERVICE MEDICARE_POS_DB.SEARCH.HCPCS_SEARCH_SVC
  TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT USAGE ON CORTEX SEARCH SERVICE MEDICARE_POS_DB.SEARCH.DEVICE_SEARCH_SVC
  TO ROLE MEDICARE_POS_INTELLIGENCE;

-- INTELLIGENCE: DML (for logging)
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.INTELLIGENCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA MEDICARE_POS_DB.INTELLIGENCE
  TO ROLE MEDICARE_POS_INTELLIGENCE;

-- GOVERNANCE: Read-only (for metadata lookups)
GRANT USAGE ON SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;
GRANT SELECT ON ALL TABLES IN SCHEMA MEDICARE_POS_DB.GOVERNANCE TO ROLE MEDICARE_POS_INTELLIGENCE;
```

**Key decisions:**
- ✅ No access to RAW or CURATED (forces use of ANALYTICS)
- ✅ Can't modify ANALYTICS (prevents accidental changes)
- ✅ Can write to INTELLIGENCE (logging)
- ✅ Can use Cortex Search services (not underlying tables)

**[GitHub Gist: full grant script](#)**

> **🔗 Reference:** See full implementation in [sql/setup/apply_grants.sql](../sql/setup/apply_grants.sql)

---

## Part 4: Star Schema Design for AI

### Why AI Loves Star Schemas

**Star schema:**
- One central fact table
- Dimension tables connected via foreign keys
- Denormalized (dimensions have repeated data, that's OK)

**Why Cortex Analyst loves this:**
1. **Simple joins** - AI knows how to join facts to dimensions
2. **Clear measures** - Fact table = numbers you aggregate (SUM, AVG, COUNT)
3. **Clear dimensions** - Dimension tables = things you slice by (state, year, product)
4. **No ambiguity** - One path from fact to dimension (not a snowflake schema maze)

**Real-world example:**

**Question:** "Average reimbursement by state"

**AI translates to:**
```sql
SELECT
  p.provider_state,
  AVG(f.avg_allowed_amount) AS avg_reimbursement
FROM ANALYTICS.FACT_DMEPOS_CLAIMS f
JOIN ANALYTICS.DIM_PROVIDER p ON f.provider_npi = p.provider_npi
GROUP BY p.provider_state
ORDER BY avg_reimbursement DESC;
```

**This works because:**
- Fact table has the measure (`avg_allowed_amount`)
- Dimension has the slice (`provider_state`)
- Join is obvious (`provider_npi`)

---

### Designing the Medicare Claims Star Schema

#### Step 1: Choose the Grain

**Grain = What does one row represent?**

Our grain: **One provider × one HCPCS code × one year**

```
Row 1: Dr. Smith × E1390 (oxygen concentrator) × 2022
Row 2: Dr. Smith × E1390 (oxygen concentrator) × 2023
Row 3: Dr. Smith × A4244 (alcohol wipes) × 2022
...
```

**Why this grain:**
- ✅ Specific enough (can aggregate up to state, specialty, etc.)
- ✅ Matches source data (CMS provides this grain)
- ✅ Not too granular (not per-claim, that's billions of rows)

---

#### Step 2: Design the Fact Table

```sql
CREATE OR REPLACE VIEW ANALYTICS.FACT_DMEPOS_CLAIMS AS
SELECT
  -- Foreign keys (connect to dimensions)
  provider_npi,           -- FK to DIM_PROVIDER
  hcpcs_code,             -- FK to DIM_DEVICE
  year,                   -- FK to DIM_DATE (if we build it)

  -- Measures (numbers you aggregate)
  total_beneficiaries,    -- COUNT of unique patients
  total_services,         -- COUNT of services rendered
  avg_allowed_amount,     -- AVG reimbursement per service

  -- Derived measures (precomputed for performance)
  total_allowed_amount    -- SUM of all reimbursements
FROM CURATED.DMEPOS_CLAIMS
GROUP BY provider_npi, hcpcs_code, year;
```

**Fact table rules:**
- ✅ Foreign keys to dimensions
- ✅ Measures are numeric (not text)
- ✅ Measures are additive (SUM makes sense) or semi-additive (AVG)
- ✅ No descriptive text (that belongs in dimensions)

---

#### Step 3: Design the Dimensions

**DIM_PROVIDER:**
```sql
CREATE OR REPLACE VIEW ANALYTICS.DIM_PROVIDER AS
SELECT DISTINCT
  provider_npi,              -- Surrogate key (unique identifier)
  provider_name,
  provider_specialty,        -- e.g., "Endocrinology", "Family Practice"
  provider_state,            -- State code (CA, NY, TX, ...)
  provider_city,
  provider_zip,
  provider_credentials       -- MD, DO, NP, etc.
FROM CURATED.DMEPOS_CLAIMS;
```

**DIM_DEVICE:**
```sql
CREATE OR REPLACE VIEW ANALYTICS.DIM_DEVICE AS
SELECT
  device_identifier,         -- Surrogate key (primaryDI)
  hcpcs_code,                -- Also a key (joins to fact)
  brand_name,
  company_name,
  device_description,        -- Used in Cortex Search
  version,
  catalog_number
FROM CURATED.GUDID_DEVICES;
```

**DIM_HCPCS (product codes):**
```sql
CREATE OR REPLACE VIEW ANALYTICS.DIM_HCPCS AS
SELECT DISTINCT
  hcpcs_code,                -- Surrogate key
  hcpcs_description,         -- e.g., "Oxygen concentrator, portable"
  hcpcs_category,            -- DME, Prosthetics, Orthotics, Supplies
  pricing_indicator          -- Fee schedule indicator
FROM CURATED.DMEPOS_CLAIMS;
```

**Dimension rules:**
- ✅ One surrogate key (unique identifier)
- ✅ Descriptive attributes (text, dates, categories)
- ✅ Slowly changing dimensions (SCD Type 2 if attributes change over time)

---

### The Complete ERD

```
┌─────────────────────┐
│   DIM_PROVIDER      │
├─────────────────────┤
│ provider_npi (PK)   │
│ provider_name       │
│ provider_specialty  │
│ provider_state      │
│ provider_city       │
└─────────────────────┘
           │
           │ 1:N
           ▼
┌────────────────────────────┐
│   FACT_DMEPOS_CLAIMS       │
├────────────────────────────┤
│ provider_npi (FK)          │◄───┐
│ hcpcs_code (FK)            │    │
│ year                       │    │
│ total_beneficiaries        │    │
│ total_services             │    │
│ avg_allowed_amount         │    │
│ total_allowed_amount       │    │
└────────────────────────────┘    │
           │                       │
           │ N:1                   │
           ▼                       │
┌─────────────────────┐            │
│   DIM_DEVICE        │            │
├─────────────────────┤            │
│ device_identifier(PK│            │
│ hcpcs_code          │────────────┘
│ brand_name          │
│ company_name        │
│ device_description  │
└─────────────────────┘
```

**[DIAGRAM PLACEHOLDER: star_schema_erd.png]**

---

## Part 5: Data Loading Patterns

### Pattern 1: JSON from API

**Source:** CMS DMEPOS API
**Format:** JSON array
**Challenge:** Nested fields, pagination

**Download script:**
```python
# data/dmepos_referring_provider_download.py
import requests
import json

API_URL = "https://data.cms.gov/provider-summary-by-type-of-service/..."
OUTPUT_FILE = "data/dmepos_referring_provider.json"
LIMIT = 5000  # Max per request

offset = 0
all_records = []

while offset < MAX_ROWS:
    response = requests.get(
        API_URL,
        params={"$limit": LIMIT, "$offset": offset}
    )
    records = response.json()
    all_records.extend(records)
    offset += LIMIT
    print(f"Downloaded {len(all_records)} records...")

with open(OUTPUT_FILE, 'w') as f:
    json.dump(all_records, f)
```

**Load into Snowflake:**
```sql
-- Create internal stage
CREATE OR REPLACE STAGE RAW.DMEPOS_STAGE;

-- Upload file (from SnowSQL)
PUT file:///path/to/dmepos_referring_provider.json @RAW.DMEPOS_STAGE
  AUTO_COMPRESS=TRUE;

-- Load into table
CREATE OR REPLACE TABLE RAW.RAW_DMEPOS (raw_data VARIANT);

COPY INTO RAW.RAW_DMEPOS
FROM @RAW.DMEPOS_STAGE/dmepos_referring_provider.json.gz
FILE_FORMAT = (TYPE = JSON STRIP_OUTER_ARRAY = TRUE)
ON_ERROR = CONTINUE;
```

**Key techniques:**
- `STRIP_OUTER_ARRAY = TRUE` - Treats each array element as a row
- `ON_ERROR = CONTINUE` - Logs bad rows but doesn't fail entire load
- `AUTO_COMPRESS = TRUE` - Saves storage costs

---

### Pattern 2: Delimited Files from ZIP

**Source:** FDA GUDID quarterly release
**Format:** Pipe-delimited (|), ZIP compressed

**Download script:**
```bash
# data/data_download.sh
GUDID_RELEASE="20240101"
URL="https://accessgudid.nlm.nih.gov/release_files/${GUDID_RELEASE}/gudid_delimited_full_release_${GUDID_RELEASE}.zip"

curl -o data/gudid.zip $URL
unzip data/gudid.zip -d data/gudid_delimited/
```

**Load into Snowflake:**
```sql
-- Create stage
CREATE OR REPLACE STAGE RAW.GUDID_STAGE;

-- Upload files
PUT file:///path/to/gudid_delimited/device.txt @RAW.GUDID_STAGE AUTO_COMPRESS=TRUE;
PUT file:///path/to/gudid_delimited/productCode.txt @RAW.GUDID_STAGE AUTO_COMPRESS=TRUE;

-- Load device catalog
CREATE OR REPLACE TABLE RAW.RAW_GUDID_DEVICE (
  primaryDI STRING,
  brandName STRING,
  companyName STRING,
  deviceDescription STRING,
  versionModelNumber STRING,
  catalogNumber STRING
);

COPY INTO RAW.RAW_GUDID_DEVICE
FROM @RAW.GUDID_STAGE/device.txt.gz
FILE_FORMAT = (
  TYPE = CSV
  FIELD_DELIMITER = '|'
  SKIP_HEADER = 1
  NULL_IF = ('NULL', 'null', '')
)
ON_ERROR = CONTINUE;
```

**Key techniques:**
- `SKIP_HEADER = 1` - Ignore column names
- `NULL_IF` - Treat empty strings as NULL
- `FIELD_DELIMITER = '|'` - Pipe-delimited

---

### Pattern 3: Incremental Loads

**Challenge:** Don't reload all data every time

**Solution: MERGE statement**

```sql
-- Incremental update for claims
MERGE INTO CURATED.DMEPOS_CLAIMS AS target
USING (
  SELECT
    $1:Rndrng_Prvdr_NPI::STRING AS provider_npi,
    $1:HCPCS_Cd::STRING AS hcpcs_code,
    $1:Tot_Benes::INT AS total_beneficiaries,
    $1:Tot_Srvcs::INT AS total_services,
    CURRENT_TIMESTAMP AS loaded_at
  FROM RAW.RAW_DMEPOS_INCREMENTAL
) AS source
ON target.provider_npi = source.provider_npi
   AND target.hcpcs_code = source.hcpcs_code
WHEN MATCHED THEN
  UPDATE SET
    total_beneficiaries = source.total_beneficiaries,
    total_services = source.total_services,
    updated_at = source.loaded_at
WHEN NOT MATCHED THEN
  INSERT (provider_npi, hcpcs_code, total_beneficiaries, total_services, loaded_at)
  VALUES (source.provider_npi, source.hcpcs_code, source.total_beneficiaries, source.total_services, source.loaded_at);
```

**Key techniques:**
- `MERGE` - Upsert (update existing, insert new)
- `ON` clause defines match key
- Track `loaded_at` and `updated_at` for audit

> **💾 Reference:** See complete implementation in [sql/ingestion/load_raw_data.sql](../sql/ingestion/load_raw_data.sql) and [sql/transform/build_curated_model.sql](../sql/transform/build_curated_model.sql)

---

## Part 6: Storage Optimization

### Problem: Cortex Queries Are Slow and Expensive

**Symptoms:**
- Queries take 30+ seconds
- High credit consumption
- Timeouts

**Root causes:**
1. Full table scans (no clustering)
2. Computing aggregates on-the-fly (no materialization)
3. Large tables without pruning
4. Poor join keys

---

### Solution 1: Clustering Keys

**What:** Tell Snowflake how to physically organize data

**Example:**
```sql
-- Cluster fact table by state and year
ALTER TABLE ANALYTICS.FACT_DMEPOS_CLAIMS
  CLUSTER BY (provider_state, year);
```

**When Cortex queries:**
```sql
SELECT * FROM FACT_DMEPOS_CLAIMS
WHERE provider_state = 'CA' AND year = 2023;
```

Snowflake only reads the micro-partitions for CA + 2023, skipping the rest.

**When to cluster:**
- ✅ Frequently filtered columns (state, year, product_category)
- ✅ Large tables (>1M rows)
- ✅ Predictable query patterns

**When NOT to cluster:**
- ❌ Low cardinality (e.g., boolean columns)
- ❌ Frequently updated tables (recluster cost)
- ❌ Random access patterns

---

### Solution 2: Materialized Views

**Problem:** Aggregates computed on every query

**Without materialization:**
```sql
-- Every query recalculates
SELECT state, SUM(total_allowed_amount)
FROM FACT_DMEPOS_CLAIMS
GROUP BY state;
```

**With materialized view:**
```sql
CREATE MATERIALIZED VIEW ANALYTICS.MV_CLAIMS_BY_STATE AS
SELECT
  provider_state,
  year,
  SUM(total_beneficiaries) AS total_beneficiaries,
  SUM(total_services) AS total_services,
  SUM(total_allowed_amount) AS total_allowed_amount,
  AVG(avg_allowed_amount) AS avg_allowed_amount
FROM ANALYTICS.FACT_DMEPOS_CLAIMS
GROUP BY provider_state, year;
```

**Query the materialized view:**
```sql
SELECT * FROM ANALYTICS.MV_CLAIMS_BY_STATE
WHERE provider_state = 'CA';
```

**Instant results** (no aggregation, just a lookup).

**Tradeoffs:**
- ✅ Faster queries (precomputed)
- ✅ Cheaper queries (less compute)
- ❌ Storage cost (duplicates data)
- ❌ Refresh lag (not real-time)

**When to materialize:**
- Common aggregations (state rollups, monthly summaries)
- Expensive joins (fact + multiple dimensions)
- Stable data (not changing every second)

---

### Solution 3: Search Services with Materialized Sources

**Problem:** Cortex Search rebuilds index on every query

**Solution: Point search service at materialized view**

```sql
-- Materialize search corpus
CREATE MATERIALIZED VIEW ANALYTICS.MV_DEVICE_SEARCH_CORPUS AS
SELECT
  device_identifier,
  hcpcs_code,
  brand_name || ' ' || device_description AS search_text
FROM ANALYTICS.DIM_DEVICE;

-- Create search service on materialized view
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  ON search_text
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT device_identifier, hcpcs_code, search_text
  FROM ANALYTICS.MV_DEVICE_SEARCH_CORPUS
);
```

**Result:** Search service refreshes every hour from materialized view (not recalculating corpus every time).

---

## Part 7: Automation with Make

### The Problem: Too Many Manual Steps

**Deployment without automation:**
1. Run setup script
2. Download data files
3. Upload to Snowflake (PUT commands)
4. Run ingestion script
5. Run curated script
6. Run analytics script
7. Run search creation script
8. Run grants script
9. Hope you didn't forget anything

**That's 9 manual steps.** Guaranteed to forget one.

---

### The Solution: Makefile

**One command:**
```bash
make demo
```

**Does everything:**

```makefile
# Makefile

SNOW ?= snow
SNOW_OPTS ?= sql -c sf_int
SNOW_CMD = $(SNOW) $(SNOW_OPTS)

.PHONY: data setup load model search grants demo

# Download data
data:
	python data/dmepos_referring_provider_download.py --max-rows 1000000
	bash data/data_download.sh

# Create schemas, roles, warehouse
setup:
	$(SNOW_CMD) -f sql/setup/setup_user_and_roles.sql

# Load raw data (assumes PUT already done)
load:
	$(SNOW_CMD) -f sql/ingestion/load_raw_data.sql

# Build curated + analytics
model:
	$(SNOW_CMD) -f sql/transform/build_curated_model.sql

# Create Cortex Search services
search:
	$(SNOW_CMD) -f sql/search/cortex_search_hcpcs.sql
	$(SNOW_CMD) -f sql/search/cortex_search_devices.sql
	$(SNOW_CMD) -f sql/search/cortex_search_providers.sql

# Apply grants
grants:
	$(SNOW_CMD) -f sql/setup/apply_grants.sql

# Full demo setup
demo: data setup load model search grants
	@echo "Demo deployment complete!"
```

**Run individual steps:**
```bash
make setup    # Just create infrastructure
make model    # Just rebuild curated + analytics
make search   # Just recreate search services
```

**[GitHub Gist: full Makefile](#)**

> **🚀 Reference:** See the full Makefile in [Makefile](../Makefile) at repo root

---

## Part 8: Real Implementation Walkthrough

### Deploying the Medicare Demo Project

**Step 1: Clone the repo**
```bash
git clone https://github.com/YOUR_USERNAME/snowflake-intelligence-medicare-pos-analyst
cd snowflake-intelligence-medicare-pos-analyst
```

**Step 2: Configure Snowflake CLI**
```bash
# Create connection profile
snow connection add sf_int \
  --account YOUR_ACCOUNT \
  --user YOUR_USER \
  --role ACCOUNTADMIN \
  --warehouse COMPUTE_WH \
  --database MEDICARE_POS_DB
```

**Step 3: Edit PUT paths**

Open `sql/ingestion/load_raw_data.sql` and update file paths:
```sql
-- Change this
PUT file:///Users/yourname/path/to/data/dmepos_referring_provider.json @RAW.DMEPOS_STAGE;

-- To your actual path
PUT file:///YOUR/ACTUAL/PATH/data/dmepos_referring_provider.json @RAW.DMEPOS_STAGE;
```

**Step 4: Run deployment**
```bash
make demo
```

**Expected output:**
```
Downloading data...
Downloaded 1,000,000 records from CMS API
Downloaded GUDID device catalog (250MB)

Creating roles and warehouse...
Role MEDICARE_POS_ADMIN created
Role MEDICARE_POS_INTELLIGENCE created
Warehouse MEDICARE_POS_WH created

Loading raw data...
Loaded 1,000,000 rows into RAW.RAW_DMEPOS
Loaded 850,000 rows into RAW.RAW_GUDID_DEVICE

Building curated model...
Created CURATED.DMEPOS_CLAIMS (987,234 rows)
Created CURATED.GUDID_DEVICES (823,456 rows)

Building analytics star schema...
Created ANALYTICS.DIM_PROVIDER (145,678 providers)
Created ANALYTICS.DIM_DEVICE (456,789 devices)
Created ANALYTICS.FACT_DMEPOS_CLAIMS (987,234 claim records)

Creating Cortex Search services...
Created SEARCH.HCPCS_SEARCH_SVC
Created SEARCH.DEVICE_SEARCH_SVC
Created SEARCH.PROVIDER_SEARCH_SVC

Applying grants...
Granted privileges to MEDICARE_POS_INTELLIGENCE

Demo deployment complete!
```

**Step 5: Verify**
```sql
-- Check row counts
SELECT 'RAW', COUNT(*) FROM RAW.RAW_DMEPOS
UNION ALL
SELECT 'CURATED', COUNT(*) FROM CURATED.DMEPOS_CLAIMS
UNION ALL
SELECT 'ANALYTICS', COUNT(*) FROM ANALYTICS.FACT_DMEPOS_CLAIMS;

-- Test search service
SELECT * FROM TABLE(SEARCH.HCPCS_SEARCH_SVC('oxygen concentrator'));
```

**[VIDEO PLACEHOLDER: 2-minute terminal recording of `make demo` execution]**

---

## Part 9: Common Pitfalls and How to Avoid Them

### Pitfall 1: Skipping the Curated Layer

**Mistake:** RAW → ANALYTICS (no CURATED in between)

**Why it fails:**
- Raw data has duplicates, nulls, type mismatches
- Analytics layer inherits all the mess
- Debugging is a nightmare ("where did this null come from?")

**Fix:** Always have a curated layer that:
- Deduplicates
- Validates (nulls, outliers, constraints)
- Types correctly
- Documents transformations

---

### Pitfall 2: Pointing Cortex at Non-Star Schemas

**Mistake:** Semantic model references snowflake schema (fact → dim1 → dim2 → dim3)

**Why it fails:**
- AI has to figure out complex join paths
- Ambiguous relationships (which path to take?)
- Slow queries (multiple joins)

**Fix:** Denormalize dimensions. Star schema, not snowflake schema.

---

### Pitfall 3: No Clustering on Large Tables

**Mistake:** 10M+ row fact table with no clustering

**Why it fails:**
- Full table scans on every query
- 45-second queries
- High costs

**Fix:** Cluster by most-filtered columns (state, year, category)

---

### Pitfall 4: Materialized Views Everywhere

**Mistake:** "Materialized views make things fast, let's materialize everything!"

**Why it fails:**
- Storage costs skyrocket (3x your data)
- Refresh costs (recomputing MVs)
- Stale data (MVs not real-time)

**Fix:** Materialize selectively:
- ✅ Common aggregations (state rollups)
- ✅ Expensive joins (fact + 3 dimensions)
- ❌ Rare queries
- ❌ Real-time data

---

### Pitfall 5: One Role to Rule Them All

**Mistake:** Everyone gets SYSADMIN role

**Why it fails:**
- No separation of duties
- Accidental deletions ("Oops, I dropped PROD")
- Compliance failures (SOX, GDPR, HIPAA)

**Fix:** Principle of least privilege:
- Data engineers: Admin role (DDL + DML)
- Analysts: Intelligence role (read analytics, use search)
- Executives: Intelligence role (no raw data access)

---

## Part 10: Cost Optimization Strategies

### Understanding Snowflake Costs for AI

**Credit consumption:**
1. **Warehouse compute** - Running queries (largest cost)
2. **Cortex Analyst** - Per-query cost (~$0.01-0.10)
3. **Cortex Search** - Indexing + query cost (~$0.005-0.05)
4. **Storage** - Data + materialized views (cheapest)

**Typical cost breakdown for 100 queries/day:**
- Warehouse: $50-200/day (depending on size)
- Cortex Analyst: $5-10/day
- Cortex Search: $2-5/day
- Storage: $0.50/day

**Total:** ~$60-220/day = $1,800-6,600/month

---

### Strategy 1: Right-Size Warehouses

**Don't use X-Large for simple queries.**

```sql
-- Create different warehouses for different workloads
CREATE WAREHOUSE ETL_WH
  WAREHOUSE_SIZE = 'LARGE'     -- For batch loads
  AUTO_SUSPEND = 60;

CREATE WAREHOUSE ANALYTICS_WH
  WAREHOUSE_SIZE = 'SMALL'     -- For BI queries
  AUTO_SUSPEND = 60;

CREATE WAREHOUSE CORTEX_WH
  WAREHOUSE_SIZE = 'XSMALL'    -- For Cortex (queries are fast)
  AUTO_SUSPEND = 60;
```

**Savings:** Using XSMALL instead of LARGE for Cortex queries = **8x cost reduction**

---

### Strategy 2: Auto-Suspend Aggressively

```sql
ALTER WAREHOUSE CORTEX_WH SET AUTO_SUSPEND = 60;  -- 1 minute
```

**Why:** Cortex queries are bursty (someone asks 5 questions, then nothing for an hour). No need to keep warehouse running.

---

### Strategy 3: Monitor Query Patterns

```sql
-- Find expensive queries
SELECT
  query_text,
  execution_time / 1000 AS seconds,
  warehouse_size,
  credits_used_cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE execution_status = 'SUCCESS'
  AND warehouse_name = 'CORTEX_WH'
  AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY credits_used_cloud_services DESC
LIMIT 20;
```

**Action:** Optimize top 20 queries (80/20 rule).

---

### Strategy 4: Cache Results

**Snowflake caches identical queries for 24 hours.**

```sql
-- First query: Runs, costs credits
SELECT AVG(total_allowed_amount) FROM FACT_DMEPOS_CLAIMS;

-- Same query within 24 hours: Free (cache hit)
SELECT AVG(total_allowed_amount) FROM FACT_DMEPOS_CLAIMS;
```

**Tip:** Encourage users to re-run queries (they'll hit cache).

---

## Conclusion: You're Now a Foundation Expert

You've learned:

✅ **Medallion architecture** (RAW → CURATED → ANALYTICS)
✅ **6-schema pattern** (separation of concerns)
✅ **Role-based access control** (least privilege)
✅ **Star schema design** (AI-friendly modeling)
✅ **Data loading patterns** (JSON, delimited, incremental)
✅ **Storage optimization** (clustering, materialization)
✅ **Automation** (Makefile, one-command deployment)
✅ **Cost optimization** (right-sizing, auto-suspend, monitoring)

**The Foundation Layer is complete.**

Now you're ready to build the Intelligence Layer on top (semantic models, search services, embeddings).

---

## What's Next

**Continue the series:**

🧠 **[Part 1: The Intelligence Layer](#)**
How to build semantic models, design search corpuses, implement embeddings, and create knowledge graphs. Turn your foundation into an AI-ready platform.

🛡️ **[Part 3: The Trust Layer](#)**
Governance, data quality, evaluation frameworks, and production readiness. Make your AI system reliable and auditable.

---

## Resources

**GitHub Repository:**
[Snowflake Intelligence Medicare Demo](https://github.com/YOUR_USERNAME/snowflake-intelligence-medicare-pos-analyst)

**Official Documentation:**
- [Snowflake Data Loading](https://docs.snowflake.com/en/user-guide/data-load)
- [Materialized Views](https://docs.snowflake.com/en/user-guide/views-materialized)
- [Clustering Keys](https://docs.snowflake.com/en/user-guide/tables-clustering-keys)

**Related Articles:**
- [The Complete Guide to Snowflake Intelligence](#) (Hub Article)
- [Medallion Architecture Explained](https://databricks.com/glossary/medallion-architecture)

---

## Let's Talk

**Questions? Comments? War stories?**

- Built a similar architecture? Share your lessons learned.
- Ran into issues? Drop a comment and I'll help troubleshoot.
- Have optimization tips? I'm all ears.

**Found this helpful?**
- ⭐ Star the [GitHub repo](https://github.com/YOUR_USERNAME/snowflake-intelligence-medicare-pos-analyst)
- 🔗 Share on LinkedIn
- 💬 Leave a comment

---

**Next up:** [The Intelligence Layer](#) - Where we turn this foundation into an AI-powered analytics platform.

*Now go build something solid. Your AI will thank you.* 🏗️
