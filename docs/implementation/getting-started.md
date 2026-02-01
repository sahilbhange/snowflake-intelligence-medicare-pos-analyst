# Execution Guide

Step-by-step instructions for deploying and running the Snowflake Intelligence Medicare POS Analyst demo.
---

## Navigation

| Want This | See This |
|-----------|----------|
| 📖 **Foundation Layer Concepts** | [Subarticle 2: The Foundation Layer](../../medium/claude/subarticle_2_foundation_layer.md) |
| 📚 **Data Model Reference** | [Data Model](data_model.md) |
| 💾 **Makefile Targets** | [Makefile](../../Makefile) |

---


---

## Project Structure

```
├── sql/
│   ├── setup/           # Infrastructure (roles, warehouse, DB/schema, grants)
│   ├── ingestion/       # Data loading (stages + COPY)
│   ├── transform/       # Data modeling (curated tables/views)
│   ├── search/          # Cortex Search services
│   ├── governance/      # Metadata, lineage, quality
│   └── intelligence/    # SF Intelligence (instrumentation, eval, tests)
├── models/              # Semantic models (YAML only)
├── docs/                # Documentation
├── data/                # Data ingestion scripts
└── scratch/             # One-time/temp scripts
```
> **📖 Deployment Context:** For architectural foundations, see [Subarticle 2: The Foundation Layer](../../medium/claude/subarticle_2_foundation_layer.md) - Understanding the "why" behind each layer

---

## Prerequisites

### Required Tools
- **Snowflake CLI** - `snow` command-line client
- **Python 3.8+** - For data download scripts
- **Make** - Build automation (standard on macOS/Linux)

### Snowflake Requirements
- Snowflake account with Cortex features enabled
- `ACCOUNTADMIN` role access (for initial setup)
- Sufficient compute credits for warehouse operations

### Configuration
1. Configure Snowflake CLI with connection named `sf_int`:
   ```bash
   snow connection add --connection-name sf_int
   ```

2. Test connection:
   ```bash
   snow sql -c sf_int -q "SELECT CURRENT_USER()"
   ```

---

## Quick Start

### Full Demo Deployment
```bash
# Download data, create objects, and deploy everything
make demo
```

### Full Deployment with Validation Framework
```bash
# Includes human validation tables and semantic tests
make deploy-all
```

---

## Step-by-Step Execution

### Phase 1: Data Download
```bash
make data
```
**What it does:**
- Downloads CMS DMEPOS Referring Provider data
- Downloads FDA GUDID device catalog data
- Stores files locally in `data/` directory

**Expected output:** CSV/JSON files in `data/` folder

### Phase 2: Snowflake Setup
```bash
make setup
```
**What it does:**
- Creates `MEDICARE_POS_INTELLIGENCE` role
- Creates `MEDICARE_POS_WH` warehouse (X-Small)
- Creates `MEDICARE_POS_DB` database
- Creates schemas: `RAW`, `CURATED`, `ANALYTICS`, `SEARCH`, `INTELLIGENCE`, `GOVERNANCE`

**Verification:**
```sql
USE ROLE MEDICARE_POS_INTELLIGENCE;
SHOW SCHEMAS IN DATABASE MEDICARE_POS_DB;
```

### Phase 3: Data Load
```bash
make load
```
**What it does:**
- Creates internal stages in RAW schema
- Uploads data files to stages (requires manual PUT or Snowsight upload)
- Creates raw tables from staged files

**Note:** You may need to run PUT commands manually:
```sql
-- Upload CMS DMEPOS JSON (created by: data/dmepos_referring_provider_download.py)
PUT file://data/dmepos_referring_provider.json @RAW.RAW_DMEPOS_STAGE AUTO_COMPRESS=TRUE;

-- Upload FDA GUDID delimited files (created by: data/data_download.sh)
PUT file://data/gudid_delimited/*.txt @RAW.RAW_GUDID_STAGE AUTO_COMPRESS=TRUE;
```

**Verification:**
```sql
SELECT COUNT(*) FROM RAW.RAW_DMEPOS;
SELECT COUNT(*) FROM RAW.RAW_GUDID_DEVICE;
```

### Phase 4: Data Model
```bash
make model
```
**What it does:**
- Creates curated tables: `CURATED.DMEPOS_CLAIMS`, `CURATED.GUDID_DEVICES`
- Creates dimension views: `ANALYTICS.DIM_PROVIDER`, `ANALYTICS.DIM_DEVICE`
- Creates fact view: `ANALYTICS.FACT_DMEPOS_CLAIMS`

**Verification:**
```sql
SELECT COUNT(*) FROM CURATED.DMEPOS_CLAIMS;
SELECT COUNT(*) FROM ANALYTICS.DIM_PROVIDER;
SELECT COUNT(*) FROM ANALYTICS.FACT_DMEPOS_CLAIMS;
```

> **📚 Reference:** Schema design and star schema patterns in [Data Model](data_model.md)

### Phase 5: Cortex Search
```bash
make search
```
**What it does:**
- Creates HCPCS Search Service in SEARCH schema
- Creates Device Search Service
- Creates Provider Search Service

**Verification:**
```sql
SHOW CORTEX SEARCH SERVICES IN SCHEMA SEARCH;
```

### Phase 6: Instrumentation
```bash
make instrumentation
```
**What it does:**
- Creates `INTELLIGENCE.ANALYST_QUERY_LOG` table
- Creates `INTELLIGENCE.ANALYST_RESPONSE_LOG` table
- Creates `INTELLIGENCE.ANALYST_EVAL_SET` table
- Seeds evaluation prompts (20 questions)

**Verification:**
```sql
SELECT COUNT(*) FROM INTELLIGENCE.ANALYST_EVAL_SET;
```

### Phase 7: Metadata
```bash
make metadata
```
**What it does:**
- Creates `GOVERNANCE.DATASET_METADATA` table
- Creates `GOVERNANCE.COLUMN_METADATA` table with sensitivity tags
- Creates `GOVERNANCE.DATA_LINEAGE` table
- Creates `GOVERNANCE.DATA_QUALITY_CHECKS` table
- Creates `GOVERNANCE.AGENT_HINTS` table
- Seeds metadata entries

**Verification:**
```sql
SELECT * FROM GOVERNANCE.DATASET_METADATA;
SELECT * FROM GOVERNANCE.COLUMN_METADATA WHERE sensitivity = 'confidential';
SELECT * FROM GOVERNANCE.AGENT_HINTS;
```

### Phase 8: Validation Framework
```bash
make validation
```
**What it does:**
- Creates `INTELLIGENCE.BUSINESS_QUESTIONS` table (10 golden questions)
- Creates `INTELLIGENCE.ANALYST_INSIGHTS` table
- Creates `INTELLIGENCE.AI_VALIDATION_RESULTS` table
- Creates `INTELLIGENCE.SEMANTIC_FEEDBACK` table
- Seeds golden questions and sample insights

**Verification:**
```sql
SELECT question_id, complexity, question_text FROM INTELLIGENCE.BUSINESS_QUESTIONS;
SELECT * FROM INTELLIGENCE.ANALYST_INSIGHTS;
```

### Phase 9: Semantic Tests
```bash
make tests
```
**What it does:**
- Runs 16 regression tests
- Stores results in `INTELLIGENCE.SEMANTIC_TEST_RESULTS`
- Creates summary views

**Verification:**
```sql
SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_SUMMARY;
SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_FAILURES;
```

---

## Semantic Model Upload

After SQL objects are created, upload the semantic model:

### Option 1: Snowsight UI
1. Navigate to Data > Databases > MEDICARE_POS_DB > Stages
2. Create (or use) stage: `ANALYTICS.CORTEX_SEM_MODEL_STG`
3. Upload `models/DMEPOS_SEMANTIC_MODEL.yaml` to that stage

### Option 2: Snowflake CLI
```sql
-- This is the stage referenced by sql/agent/cortex_agent.sql and used for agent creation.
CREATE STAGE IF NOT EXISTS ANALYTICS.CORTEX_SEM_MODEL_STG;
PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @ANALYTICS.CORTEX_SEM_MODEL_STG AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

### Option 3: Snowflake Intelligence UI
1. Go to Snowflake Intelligence
2. Create a new Analyst source
3. Upload the YAML file directly

---

## Snowflake Intelligence Configuration

### Configure Analyst Source
1. Open Snowflake Intelligence in Snowsight
2. Click "Add Source" > "Cortex Analyst"
3. Upload or reference `DMEPOS_SEMANTIC_MODEL.yaml`
4. Name the source: "Medicare DMEPOS Claims"

### Configure Search Sources
1. Click "Add Source" > "Cortex Search"
2. Add each search service from SEARCH schema:
   - HCPCS_SEARCH_SVC
   - DEVICE_SEARCH_SVC
   - PROVIDER_SEARCH_SVC

### Test Configuration
Try these prompts:
- "What are the top 5 HCPCS codes by total claims?"
- "Show me California providers with highest claim volume"
- "What is HCPCS E1390?"

---

## Verification Checklist

After deployment, verify:

### Data Objects
```sql
-- Check row counts
SELECT 'CURATED.DMEPOS_CLAIMS' as tbl, COUNT(*) as rows FROM CURATED.DMEPOS_CLAIMS
UNION ALL SELECT 'ANALYTICS.DIM_PROVIDER', COUNT(*) FROM ANALYTICS.DIM_PROVIDER
UNION ALL SELECT 'CURATED.GUDID_DEVICES', COUNT(*) FROM CURATED.GUDID_DEVICES;
```

### Semantic Tests
```sql
-- All tests should pass
SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_SUMMARY;
-- No failures expected
SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_FAILURES;
```

### Metadata Coverage
```sql
-- Check metadata coverage
SELECT dataset_name, COUNT(*) as columns_documented
FROM GOVERNANCE.COLUMN_METADATA
GROUP BY dataset_name;
```

### Validation Framework
```sql
-- Check golden questions
SELECT COUNT(*) as golden_questions FROM INTELLIGENCE.BUSINESS_QUESTIONS;
-- Should be 10
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `Object does not exist` | Run setup scripts in order |
| `Insufficient privileges` | Switch to `MEDICARE_POS_INTELLIGENCE` role |
| `Warehouse suspended` | Resume with `ALTER WAREHOUSE MEDICARE_POS_WH RESUME` |
| `PUT command fails` | Use Snowsight UI for file upload |
| `Cortex Search not available` | Check account has Cortex features enabled |

### Reset and Redeploy
```sql
-- Drop and recreate (CAUTION: deletes all data)
DROP DATABASE IF EXISTS MEDICARE_POS_DB;
-- Then run: make demo
```

---

## Make Targets Reference

| Target | Description |
|--------|-------------|
| `make data` | Download source data files |
| `make setup` | Create Snowflake objects (roles, warehouse, database, schemas) |
| `make load` | Load raw data into RAW schema |
| `make model` | Build CURATED tables and ANALYTICS views |
| `make search` | Create Cortex Search services in SEARCH schema |
| `make instrumentation` | Create logging and eval tables in INTELLIGENCE |
| `make metadata` | Create metadata tables in GOVERNANCE |
| `make validation` | Create human validation framework in INTELLIGENCE |
| `make tests` | Run semantic model tests |
| `make demo` | Full demo setup (recommended) |
| `make deploy-all` | Full deployment with validation |
| `make verify` | Run tests to verify deployment |
| `make help` | Show all available targets |

> **💾 Reference:** All Make targets are defined in [Makefile](../../Makefile)

---

## Schema Reference

| Schema | Layer | Purpose |
|--------|-------|---------|
| RAW | Bronze | Raw landing tables and stages |
| CURATED | Silver | Cleaned and typed tables |
| ANALYTICS | Gold | Dimension and fact views |
| SEARCH | - | Cortex Search services |
| INTELLIGENCE | - | SF Intelligence instrumentation |
| GOVERNANCE | - | Metadata, lineage, quality |

---

## Post-Deployment Tasks

### 1. Human Validation (Recommended)
- Build 3 dashboards in Snowsight
- Document insights in `INTELLIGENCE.ANALYST_INSIGHTS`
- Test AI against golden questions
- Log results in `INTELLIGENCE.AI_VALIDATION_RESULTS`

### 2. Monitoring Setup
- Enable query logging to `INTELLIGENCE.ANALYST_QUERY_LOG`
- Review `INTELLIGENCE.SEMANTIC_FEEDBACK` regularly
- Monitor `GOVERNANCE.DATA_QUALITY_RESULTS`

### 3. Documentation Review
- Review [Metric Catalog](../reference/metric_catalog.md)
- Review [Agent Guidance](../reference/agent_guidance.md)
- Complete [Publish Checklist](../governance/semantic_publish_checklist.md)

---

## Related Documentation

- [Data Model](data_model.md)
- [Snowflake Intelligence Setup](snowflake_intelligence_setup.md)
- [Data Dictionary](../governance/data_dictionary.md)
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md)
- [Publish Checklist](../governance/semantic_publish_checklist.md)
- [Metric Catalog](../reference/metric_catalog.md)
- [Agent Guidance](../reference/agent_guidance.md)
