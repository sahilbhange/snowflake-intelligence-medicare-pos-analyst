# Snowflake Intelligence Setup

Configure Snowflake Intelligence UI to use Cortex Search services and semantic models.

---

## Prerequisites

Before starting, ensure:
- [ ] `MEDICARE_POS_DB.ANALYTICS` schema exists
- [ ] Cortex Search services are created (`HCPCS_SEARCH_SVC`, `DEVICE_SEARCH_SVC`, `PROVIDER_SEARCH_SVC`)
- [ ] Semantic model `DMEPOS_SEMANTIC_MODEL.yaml` is uploaded to a stage or local file
- [ ] You have `USAGE` privileges on the database and warehouse

**See:** [Getting Started](getting-started.md) for full deployment instructions.

---

## Step 1: Access Snowflake Intelligence

1. Log in to Snowsight
2. Navigate to **AI & ML** → **Snowflake Intelligence** (in left sidebar)
3. Click **Get Started** if this is your first time

**Screenshot placeholder:** Snowsight navigation to Snowflake Intelligence

---

## Step 2: Add Cortex Analyst Source (Semantic Model)

### Upload Semantic Model

1. Click **Add Source** button
2. Select **Cortex Analyst**
3. Choose upload method:
   - **Option A:** Upload YAML file directly
   - **Option B:** Reference file in Snowflake stage

**For Option A (Direct Upload):**
```
1. Click "Upload File"
2. Select: models/DMEPOS_SEMANTIC_MODEL.yaml
3. Name: "Medicare DMEPOS Claims"
4. Description: "Medicare Part B DMEPOS claims by provider and HCPCS code"
5. Click "Create"
```

**For Option B (Stage Reference):**
```sql
-- First, upload to stage
CREATE STAGE IF NOT EXISTS ANALYTICS.SEMANTIC_MODELS;

PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml
  @ANALYTICS.SEMANTIC_MODELS
  AUTO_COMPRESS=FALSE
  OVERWRITE=TRUE;

-- Then in Snowflake Intelligence UI:
1. Select "From Stage"
2. Stage: ANALYTICS.SEMANTIC_MODELS
3. File: DMEPOS_SEMANTIC_MODEL.yaml
4. Name: "Medicare DMEPOS Claims"
5. Click "Create"
```

**Verification:**
- Ask a test question: "What are the top 5 HCPCS codes by claims?"
- Should generate SQL and return results

---

## Step 3: Add Cortex Search Sources

### Service 1: HCPCS Search

1. Click **Add Source** → **Cortex Search Service**
2. Configure:
   - **Database:** MEDICARE_POS_DB
   - **Schema:** SEARCH
   - **Service Name:** HCPCS_SEARCH_SVC
   - **Display Name:** "HCPCS Code Definitions"
   - **Description:** "HCPCS procedure code definitions and rental indicators"
   - **Max Results:** 5
3. Click **Create**

**Test query:** "What is HCPCS code E1390?"

---

### Service 2: Device Search

1. Click **Add Source** → **Cortex Search Service**
2. Configure:
   - **Database:** MEDICARE_POS_DB
   - **Schema:** SEARCH
   - **Service Name:** DEVICE_SEARCH_SVC
   - **Display Name:** "Medical Device Catalog"
   - **Description:** "FDA GUDID medical device catalog with brands and descriptions"
   - **Max Results:** 5
3. Click **Create**

**Test query:** "Find oxygen concentrators"

---

### Service 3: Provider Search

1. Click **Add Source** → **Cortex Search Service**
2. Configure:
   - **Database:** MEDICARE_POS_DB
   - **Schema:** SEARCH
   - **Service Name:** PROVIDER_SEARCH_SVC
   - **Display Name:** "Provider Directory"
   - **Description:** "Medicare provider specialties and locations"
   - **Max Results:** 5
3. Click **Create**

**Test query:** "Find endocrinologists in California"

---

## Step 4: Test Intelligence Routing

Snowflake Intelligence automatically routes questions to the appropriate source.

### Test Queries

| Question | Expected Source | Expected Behavior |
|----------|-----------------|-------------------|
| "Top 10 states by claim volume" | Cortex Analyst | Generates SQL, returns aggregation |
| "What is HCPCS E1390?" | HCPCS Search | Returns definition from search corpus |
| "Find wheelchair devices" | Device Search | Returns device catalog matches |
| "Providers in Texas" | Analyst + Provider Search | Hybrid: count from Analyst, details from Search |

**Screenshot placeholder:** Snowflake Intelligence answering a hybrid question

---

## Step 5: Configure Permissions (Optional)

### Grant Access to Other Users

```sql
-- Grant usage on search services
GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC
  TO ROLE MEDICARE_POS_USER;

GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  TO ROLE MEDICARE_POS_USER;

GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.PROVIDER_SEARCH_SVC
  TO ROLE MEDICARE_POS_USER;

-- Grant usage on semantic model stage
GRANT USAGE ON STAGE ANALYTICS.SEMANTIC_MODELS
  TO ROLE MEDICARE_POS_USER;
```

---

## Troubleshooting

### Issue: Cortex Analyst Returns "No data"

**Causes:**
- Semantic model not uploaded correctly
- Database/schema names incorrect in YAML
- No grants on underlying tables

**Solution:**
```sql
-- Verify semantic model references correct objects
SHOW TABLES IN ANALYTICS;

-- Grant SELECT on tables
GRANT SELECT ON ALL TABLES IN SCHEMA ANALYTICS
  TO ROLE MEDICARE_POS_INTELLIGENCE;
```

---

### Issue: Search Service Not Found

**Causes:**
- Service not created yet
- Wrong database/schema selected
- No grants on service

**Solution:**
```sql
-- Verify services exist
SHOW CORTEX SEARCH SERVICES IN SEARCH;

-- Grant usage
GRANT USAGE ON CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC
  TO ROLE CURRENT_ROLE();
```

---

### Issue: "Failed to generate SQL"

**Causes:**
- Ambiguous question
- Missing metrics or dimensions in semantic model
- Question requires complex joins not defined

**Solution:**
- Rephrase question more specifically
- Add verified queries to semantic model for similar patterns
- Check [Agent Guidance](../reference/agent_guidance.md) for routing rules

---

### Issue: Slow Response Times

**Causes:**
- Warehouse suspended
- Large result sets
- Search service lag

**Solution:**
```sql
-- Resume warehouse
ALTER WAREHOUSE MEDICARE_POS_WH RESUME;

-- Check warehouse size
SHOW WAREHOUSES LIKE 'MEDICARE_POS_WH';

-- Refresh search services
ALTER CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC REFRESH;
```

---

## Integration with Getting Started Guide

This setup is **Step 8** in the [Getting Started](getting-started.md) deployment guide.

**Execution order:**
1. Run `make demo` (creates all objects)
2. Upload semantic model (this guide, Step 2)
3. Configure Snowflake Intelligence UI (this guide, Steps 2-3)
4. Test queries (this guide, Step 4)

---

## Advanced Configuration

### Add PDF Search Service (Optional)

If you've set up RAG with PDF corpus:

1. Click **Add Source** → **Cortex Search Service**
2. Configure:
   - **Service Name:** PDF_SEARCH_SVC
   - **Display Name:** "CMS Policy Documents"
   - **Description:** "CMS DMEPOS policy manuals and fee schedule guidance"
3. Test: "What does CMS say about DMEPOS rentals?"

**See:** [PDF Sources](../reference/pdf_sources.md) for PDF corpus setup.

---

### Configure Query Logging (Recommended)

Enable query logging to track usage and improve the semantic model:

```sql
-- Create logging stream
CREATE OR REPLACE TABLE INTELLIGENCE.ANALYST_QUERY_LOG (
  query_id STRING,
  user_name STRING,
  question TEXT,
  generated_sql TEXT,
  was_successful BOOLEAN,
  error_message TEXT,
  query_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Log queries via Snowsight (manual process)
-- Or use Snowflake query history:
INSERT INTO INTELLIGENCE.ANALYST_QUERY_LOG
SELECT
  query_id,
  user_name,
  query_text AS question,
  NULL AS generated_sql,
  execution_status = 'SUCCESS' AS was_successful,
  error_message,
  start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%FACT_DMEPOS_CLAIMS%'
  AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP());
```

---

## Related Documentation

- [Getting Started](getting-started.md) - Full deployment guide
- [Agent Guidance](../reference/agent_guidance.md) - Question routing rules
- [Metric Catalog](../reference/metric_catalog.md) - Available metrics
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md) - Version management

---

## Quick Validation Checklist

After setup, verify:
- [ ] Cortex Analyst source shows "Active"
- [ ] All 3 search services show "Active"
- [ ] Test query returns results (no errors)
- [ ] Hybrid question routes to multiple sources
- [ ] Generated SQL is syntactically correct
- [ ] Results match expected format

**If all checks pass:** ✅ Snowflake Intelligence is ready to use!

---

## Video Tutorial Placeholder

**Recommended:** Record a 2-minute walkthrough showing:
1. Adding Cortex Analyst source
2. Adding search services
3. Testing 3 sample questions
4. Showing results

**See:** [Video Recording Guide](../../medium/claude/video_recording_guide.md)
