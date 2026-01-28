# The Trust Layer: Governance, Quality, and Evolution for Production AI

*Or: How to Sleep at Night When AI is Answering Your CEO's Questions*

---

**Part of the series:** [The Complete Guide to Snowflake Intelligence](#) (Hub Article)

**Navigation:**
- 🧠 [Part 1: The Intelligence Layer](subarticle_1_intelligence_layer.md) - How AI understands your data
- 🏗️ [Part 2: The Foundation Layer](subarticle_2_foundation_layer.md) - Architecture and data engineering
- 🛡️ **Part 3: The Trust Layer** (You are here)

**Quick Links:**
| Want This | See This |
|-----------|----------|
| Semantic model versioning guide | [Docs: Lifecycle](../docs/governance/semantic_model_lifecycle.md) |
| Human validation framework | [Docs: Validation Log](../docs/governance/human_validation_log.md) |
| Working governance SQL | [SQL: Metadata](../sql/governance/metadata_and_quality.sql) |

---

## The 2 AM Slack Message

It's 2:07 AM. Your phone vibrates.

**CEO (via Slack):** "Why did the Q4 numbers change?"

**You:** *Groggily opens laptop* "What Q4 numbers?"

**CEO:** "The revenue by state report I pulled last week from the AI. I ran the same query today and the numbers are completely different."

**You:** *Panic intensifies* "Let me investigate..."

**30 minutes later, you discover:**
- Someone updated the semantic model yesterday (no changelog)
- The update changed the definition of "revenue" (net → gross)
- No regression tests were run
- No one was notified
- The AI has been giving wrong answers for 18 hours
- The board meeting is in 6 hours

**This is what happens when you skip the Trust Layer.**

---

## The Inconvenient Truth About AI in Production

You can build the perfect:
- ✅ Data architecture (medallion, star schema, optimized)
- ✅ Semantic models (comprehensive, well-documented)
- ✅ Search services (hybrid, fast, accurate)

**But if you can't answer these questions, you're not production-ready:**

1. **Who queried what, and when?** (Audit trail)
2. **Is the AI giving correct answers?** (Evaluation)
3. **How do I know when something breaks?** (Monitoring)
4. **Can I roll back a bad change?** (Versioning)
5. **How does the system improve over time?** (Feedback loops)

**This article is about building the Trust Layer** - the unsexy infrastructure that makes AI systems reliable, auditable, and continuously improving.

---

## What You'll Learn

By the end of this deep dive, you'll know:

1. **AI Governance** - Metadata, lineage, access control, audit trails
2. **Data Quality for AI** - Profiling, monitoring, semantic drift detection
3. **Evaluation Frameworks** - Instrumentation, eval seeds, regression testing
4. **Model Evolution** - Versioning, change management, deprecation patterns
5. **Feedback Loops** - Human validation, continuous improvement

**Estimated reading time:** 20-25 minutes

**Code repository:** [GitHub - Snowflake Intelligence Medicare Demo](#)

Let's build trust.

---

## Part 1: AI Governance - It's Just Data Governance (But More)

### Traditional Data Governance

**What it covers:**
- Data quality (nulls, duplicates, outliers)
- Metadata (column descriptions)
- Lineage (where did this data come from?)
- Access control (who can see what?)
- Compliance (PII, GDPR, HIPAA)

**AI Governance adds:**
- ❗ **AI-specific quality** (semantic drift, embedding staleness)
- ❗ **Model lineage** (which semantic model version generated this answer?)
- ❗ **Query logging** (who asked what, what SQL was generated?)
- ❗ **Evaluation tracking** (how accurate is the AI?)
- ❗ **Feedback collection** (was this answer helpful?)

**It's the same principles, but AI systems generate new types of metadata.**

---

### Building a Metadata Catalog

**You already have this from Part 1 (Intelligence Layer), but let's expand it for governance:**

```sql
-- Comprehensive metadata catalog
CREATE TABLE GOVERNANCE.COLUMN_METADATA (
  schema_name STRING,
  table_name STRING,
  column_name STRING,

  -- Business context
  business_name STRING,
  business_definition STRING,
  business_owner STRING,

  -- Technical context
  data_type STRING,
  is_nullable BOOLEAN,
  default_value STRING,

  -- Governance
  sensitivity_level STRING,  -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
  contains_pii BOOLEAN,
  contains_phi BOOLEAN,       -- Protected Health Information (HIPAA)
  gdpr_classification STRING, -- PERSONAL_DATA, SENSITIVE_DATA, NONE
  retention_policy STRING,    -- How long to keep this data

  -- Quality
  valid_values STRING,        -- Enumerated list or pattern
  min_value VARIANT,
  max_value VARIANT,
  sample_values STRING,

  -- Audit
  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  updated_by STRING
);
```

**Example: Marking PII/PHI columns**

```sql
INSERT INTO GOVERNANCE.COLUMN_METADATA VALUES (
  'ANALYTICS',
  'DIM_PROVIDER',
  'provider_npi',
  'Provider National Provider Identifier',
  'Unique 10-digit identifier assigned by CMS to healthcare providers.',
  'data_governance@company.com',
  'STRING(10)',
  FALSE,
  NULL,
  'CONFIDENTIAL',
  TRUE,   -- Contains PII
  TRUE,   -- Contains PHI (HIPAA applies)
  'PERSONAL_DATA',  -- GDPR
  '7 years after last service',
  '^[0-9]{10}$',
  NULL,
  NULL,
  '["1234567890", "9876543210"]',
  CURRENT_TIMESTAMP(),
  CURRENT_TIMESTAMP(),
  'governance_automation'
);
```

**Use cases:**
1. **Compliance audits** - "Show me all PHI columns accessible by INTELLIGENCE role"
2. **AI context** - Include sensitivity in semantic model (AI can warn users about PII)
3. **Access control** - Auto-generate row-level security policies based on sensitivity

---

### Table Lineage Tracking

**Why it matters:** When upstream data changes, downstream semantic models need to be re-evaluated.

```sql
CREATE TABLE GOVERNANCE.TABLE_LINEAGE (
  target_table STRING,
  source_table STRING,
  lineage_type STRING,  -- DIRECT (table created from), INDIRECT (joins)
  transformation_sql STRING,  -- How is target derived from source?
  last_refresh TIMESTAMP
);

-- Example: FACT table depends on CURATED table
INSERT INTO GOVERNANCE.TABLE_LINEAGE VALUES (
  'ANALYTICS.FACT_DMEPOS_CLAIMS',
  'CURATED.DMEPOS_CLAIMS',
  'DIRECT',
  'CREATE VIEW ANALYTICS.FACT_DMEPOS_CLAIMS AS SELECT ... FROM CURATED.DMEPOS_CLAIMS GROUP BY ...',
  CURRENT_TIMESTAMP()
);

-- Semantic model depends on FACT table
INSERT INTO GOVERNANCE.TABLE_LINEAGE VALUES (
  'SEMANTIC_MODEL.DMEPOS_ANALYST',
  'ANALYTICS.FACT_DMEPOS_CLAIMS',
  'INDIRECT',
  'Semantic model references FACT_DMEPOS_CLAIMS for measures and dimensions',
  CURRENT_TIMESTAMP()
);
```

**Impact analysis query:**

```sql
-- If CURATED.DMEPOS_CLAIMS changes, what's affected?
WITH RECURSIVE lineage AS (
  SELECT target_table, source_table, 1 AS depth
  FROM GOVERNANCE.TABLE_LINEAGE
  WHERE source_table = 'CURATED.DMEPOS_CLAIMS'

  UNION ALL

  SELECT l.target_table, l.source_table, lineage.depth + 1
  FROM GOVERNANCE.TABLE_LINEAGE l
  JOIN lineage ON l.source_table = lineage.target_table
  WHERE lineage.depth < 5  -- Prevent infinite recursion
)
SELECT DISTINCT target_table, depth
FROM lineage
ORDER BY depth;
```

**Result:**
```
TARGET_TABLE                        | DEPTH
------------------------------------+-------
ANALYTICS.FACT_DMEPOS_CLAIMS        | 1
SEMANTIC_MODEL.DMEPOS_ANALYST       | 2
INTELLIGENCE.EVAL_SEED_RESULTS      | 3
```

**Action:** Re-test semantic model and eval seeds after upstream changes.

---

### Access Control for AI

**Problem:** Not everyone should query everything.

**Solution: Role-based access control (RBAC)**

**Roles we defined in Part 2 (Foundation Layer):**
1. **MEDICARE_POS_ADMIN** - Data engineers (full access)
2. **MEDICARE_POS_INTELLIGENCE** - AI + business users (read analytics, use search, write logs)

**But what if you need finer control?**

---

#### Row-Level Security (RLS)

**Scenario:** Executives can see all states, regional managers can only see their region.

```sql
-- Create mapping table
CREATE TABLE GOVERNANCE.USER_REGION_ACCESS (
  snowflake_user STRING,
  allowed_states ARRAY
);

INSERT INTO GOVERNANCE.USER_REGION_ACCESS VALUES
  ('CEO@COMPANY.COM', ARRAY_CONSTRUCT('CA', 'NY', 'TX', 'FL', 'ALL')),  -- All states
  ('WEST_REGION_MANAGER@COMPANY.COM', ARRAY_CONSTRUCT('CA', 'NV', 'OR', 'WA'));

-- Create row access policy
CREATE OR REPLACE ROW ACCESS POLICY ANALYTICS.STATE_ACCESS_POLICY
AS (provider_state STRING) RETURNS BOOLEAN ->
  CASE
    WHEN CURRENT_ROLE() = 'MEDICARE_POS_ADMIN' THEN TRUE  -- Admins see everything
    WHEN EXISTS (
      SELECT 1
      FROM GOVERNANCE.USER_REGION_ACCESS
      WHERE snowflake_user = CURRENT_USER()
        AND (ARRAY_CONTAINS('ALL'::VARIANT, allowed_states)
             OR ARRAY_CONTAINS(provider_state::VARIANT, allowed_states))
    ) THEN TRUE
    ELSE FALSE
  END;

-- Apply policy to fact table
ALTER TABLE ANALYTICS.FACT_DMEPOS_CLAIMS
  ADD ROW ACCESS POLICY ANALYTICS.STATE_ACCESS_POLICY ON (provider_state);
```

**Result:**
- CEO queries "top states by volume" → sees all states
- West region manager queries same → only sees CA, NV, OR, WA
- **Cortex Analyst respects row-level security automatically**

---

#### Column-Level Security (Dynamic Data Masking)

**Scenario:** Analysts can see provider aggregates, but not individual NPIs (PII).

```sql
-- Create masking policy
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MASK_PII
AS (val STRING) RETURNS STRING ->
  CASE
    WHEN CURRENT_ROLE() IN ('MEDICARE_POS_ADMIN', 'COMPLIANCE_OFFICER') THEN val
    ELSE '***MASKED***'
  END;

-- Apply to PII column
ALTER TABLE ANALYTICS.DIM_PROVIDER
  MODIFY COLUMN provider_npi
  SET MASKING POLICY GOVERNANCE.MASK_PII;
```

**Result:**
- Admin queries `SELECT provider_npi FROM DIM_PROVIDER` → sees actual NPIs
- Analyst queries same → sees `***MASKED***`
- Cortex Analyst can still aggregate (COUNT DISTINCT provider_npi works), but can't return individual values

---

### Audit Logging

**Track who asked what, when:**

```sql
CREATE TABLE INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG (
  query_id STRING,
  user_name STRING,
  user_role STRING,
  question TEXT,
  generated_sql TEXT,
  execution_time_ms NUMBER,
  rows_returned NUMBER,
  error_message STRING,
  semantic_model_version STRING,
  query_timestamp TIMESTAMP
);

-- Populate via query history (run daily)
INSERT INTO INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG
SELECT
  query_id,
  user_name,
  role_name,
  query_text AS question,
  NULL AS generated_sql,  -- Extract from query_text if possible
  execution_time,
  rows_produced,
  error_message,
  'v1.2.3' AS semantic_model_version,  -- Track manually or extract from model
  start_time
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%CORTEX.ANALYST%'
  AND start_time > DATEADD(day, -1, CURRENT_TIMESTAMP());
```

**Compliance queries:**

```sql
-- Who accessed PHI data in the last 30 days?
SELECT DISTINCT user_name, COUNT(*) AS query_count
FROM INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG
WHERE generated_sql ILIKE '%provider_npi%'  -- PHI column
  AND query_timestamp > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY user_name
ORDER BY query_count DESC;

-- Most expensive queries (for cost attribution)
SELECT
  user_name,
  question,
  execution_time_ms,
  rows_returned
FROM INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG
WHERE query_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY execution_time_ms DESC
LIMIT 20;
```

> **🔗 Reference:** See full implementation in [sql/intelligence/instrumentation.sql](../sql/intelligence/instrumentation.sql)

---

## Part 2: Data Quality for AI

### Traditional Data Quality

**Checks we all run:**
- ❌ Null check: `SELECT COUNT(*) FROM table WHERE critical_column IS NULL`
- ❌ Duplicate check: `SELECT col, COUNT(*) FROM table GROUP BY col HAVING COUNT(*) > 1`
- ❌ Outlier check: `SELECT * FROM table WHERE amount < 0 OR amount > 1000000`

**These are necessary but not sufficient for AI.**

---

### AI-Specific Data Quality

**New quality dimensions:**

1. **Semantic consistency** - Do column values match their definitions?
2. **Temporal drift** - Are distributions changing over time?
3. **Embedding staleness** - Are embeddings out of sync with source text?
4. **Relationship validity** - Do foreign keys still exist?
5. **Model accuracy drift** - Is the semantic model still generating correct queries?

Let's build checks for each.

---

### Semantic Consistency

**Problem:** Column metadata says "valid values: P, A, D, R" but actual data has "PENDING", "APPROVED"

**Check:**
```sql
-- Check for invalid values
WITH metadata AS (
  SELECT
    table_name,
    column_name,
    valid_values
  FROM GOVERNANCE.COLUMN_METADATA
  WHERE valid_values IS NOT NULL
),
actual_values AS (
  SELECT DISTINCT
    'FACT_DMEPOS_CLAIMS' AS table_name,
    'claim_status' AS column_name,
    claim_status AS actual_value
  FROM ANALYTICS.FACT_DMEPOS_CLAIMS
)
SELECT
  av.table_name,
  av.column_name,
  av.actual_value,
  m.valid_values
FROM actual_values av
JOIN metadata m
  ON av.table_name = m.table_name
  AND av.column_name = m.column_name
WHERE av.actual_value NOT IN (
  SELECT VALUE FROM TABLE(SPLIT_TO_TABLE(m.valid_values, ','))
);
```

**Automated fix:**
- Flag as quality issue
- Alert data governance team
- Update metadata OR clean data

---

### Temporal Drift Detection

**Problem:** Data distributions change over time, AI model doesn't adapt

**Example:**
- January: Average claim amount = $250
- June: Average claim amount = $450 (new high-cost devices approved)
- Semantic model still assumes $250 as "typical"

**Detection:**
```sql
CREATE TABLE GOVERNANCE.PROFILE_HISTORY (
  table_name STRING,
  column_name STRING,
  profile_date DATE,
  row_count NUMBER,
  null_count NUMBER,
  null_pct FLOAT,
  distinct_count NUMBER,
  min_value VARIANT,
  max_value VARIANT,
  avg_value FLOAT,
  stddev_value FLOAT
);

-- Run weekly profiling
INSERT INTO GOVERNANCE.PROFILE_HISTORY
SELECT
  'FACT_DMEPOS_CLAIMS' AS table_name,
  'avg_allowed_amount' AS column_name,
  CURRENT_DATE() AS profile_date,
  COUNT(*) AS row_count,
  COUNT_IF(avg_allowed_amount IS NULL) AS null_count,
  (null_count / row_count * 100) AS null_pct,
  COUNT(DISTINCT avg_allowed_amount) AS distinct_count,
  MIN(avg_allowed_amount) AS min_value,
  MAX(avg_allowed_amount) AS max_value,
  AVG(avg_allowed_amount) AS avg_value,
  STDDEV(avg_allowed_amount) AS stddev_value
FROM ANALYTICS.FACT_DMEPOS_CLAIMS;

-- Detect drift (compare to 30 days ago)
WITH current_profile AS (
  SELECT * FROM GOVERNANCE.PROFILE_HISTORY
  WHERE profile_date = CURRENT_DATE()
),
baseline_profile AS (
  SELECT * FROM GOVERNANCE.PROFILE_HISTORY
  WHERE profile_date = DATEADD(day, -30, CURRENT_DATE())
)
SELECT
  c.table_name,
  c.column_name,
  b.avg_value AS baseline_avg,
  c.avg_value AS current_avg,
  ((c.avg_value - b.avg_value) / b.avg_value * 100) AS pct_change
FROM current_profile c
JOIN baseline_profile b
  ON c.table_name = b.table_name
  AND c.column_name = b.column_name
WHERE ABS((c.avg_value - b.avg_value) / b.avg_value * 100) > 20  -- Alert if >20% change
ORDER BY ABS(pct_change) DESC;
```

**Alert:**
> ⚠️ Semantic Drift Detected
> Table: FACT_DMEPOS_CLAIMS
> Column: avg_allowed_amount
> Baseline average (30 days ago): $250
> Current average: $450 (+80% change)
> Action: Review semantic model, update "typical values" description

---

### Embedding Staleness

**Problem:** Text changed but embeddings weren't recomputed

**Example:**
- Device description updated: "Oxygen concentrator" → "Oxygen concentrator with pulse dose"
- Embedding still represents old text
- Search results are wrong

**Check:**
```sql
CREATE TABLE GOVERNANCE.EMBEDDING_STALENESS_CHECK (
  table_name STRING,
  row_id STRING,
  text_column STRING,
  text_hash STRING,
  embedding_hash STRING,
  text_updated_at TIMESTAMP,
  embedding_updated_at TIMESTAMP
);

-- Detect stale embeddings
INSERT INTO GOVERNANCE.EMBEDDING_STALENESS_CHECK
SELECT
  'DIM_DEVICE' AS table_name,
  device_identifier AS row_id,
  'device_description' AS text_column,
  SHA2(device_description) AS text_hash,
  SHA2(device_description_embedding::STRING) AS embedding_hash,
  updated_at AS text_updated_at,
  embedding_updated_at
FROM ANALYTICS.DIM_DEVICE
WHERE updated_at > embedding_updated_at;  -- Text changed after embedding

-- Alert
SELECT COUNT(*) AS stale_embeddings
FROM GOVERNANCE.EMBEDDING_STALENESS_CHECK
WHERE text_updated_at > embedding_updated_at;
```

**Automated fix:**
```sql
-- Recompute stale embeddings
UPDATE ANALYTICS.DIM_DEVICE
SET
  device_description_embedding = SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
    'snowflake-arctic-embed-l',
    device_description
  ),
  embedding_updated_at = CURRENT_TIMESTAMP()
WHERE device_identifier IN (
  SELECT row_id
  FROM GOVERNANCE.EMBEDDING_STALENESS_CHECK
  WHERE text_updated_at > embedding_updated_at
);
```

---

### Relationship Validity (Referential Integrity)

**Problem:** Foreign keys point to non-existent rows

**Example:**
- FACT table has provider_npi = '1234567890'
- DIM_PROVIDER doesn't have that NPI (provider was deleted)
- Cortex Analyst joins fail or return incomplete results

**Check:**
```sql
-- Find orphaned rows
SELECT
  f.provider_npi,
  COUNT(*) AS orphaned_rows
FROM ANALYTICS.FACT_DMEPOS_CLAIMS f
LEFT JOIN ANALYTICS.DIM_PROVIDER p ON f.provider_npi = p.provider_npi
WHERE p.provider_npi IS NULL
GROUP BY f.provider_npi;
```

**Automated fix:**
- Option 1: Insert missing provider (placeholder record)
- Option 2: Delete orphaned fact rows
- Option 3: Alert data governance to investigate

> **📊 Reference:** See full implementation in [sql/governance/metadata_and_quality.sql](../sql/governance/metadata_and_quality.sql) and [sql/governance/run_profiling.sql](../sql/governance/run_profiling.sql)

---

## Part 3: Evaluation Frameworks

### The Golden Question: "Is AI Giving Correct Answers?"

**Traditional software testing:**
- Write unit test
- Run unit test
- Test passes or fails

**AI testing is harder:**
- Questions are open-ended
- "Correct" answer may vary (top 10 vs top 5 states)
- SQL can be written many ways (all correct)

**Solution: Evaluation frameworks**

---

### Evaluation Seed (Golden Questions)

**Eval seed** = A curated set of questions with known-good SQL and expected results.

```sql
CREATE TABLE INTELLIGENCE.EVAL_SEED_QUESTIONS (
  question_id STRING,
  question_text STRING,
  expected_sql TEXT,
  expected_result_sample VARIANT,  -- JSON sample of first few rows
  semantic_model_version STRING,
  created_at TIMESTAMP,
  created_by STRING
);

-- Example seed questions
INSERT INTO INTELLIGENCE.EVAL_SEED_QUESTIONS VALUES
  ('Q001',
   'What are the top 10 states by total claim volume?',
   'SELECT provider_state, SUM(total_services) AS volume FROM ANALYTICS.FACT_DMEPOS_CLAIMS GROUP BY provider_state ORDER BY volume DESC LIMIT 10',
   '{"sample": [{"provider_state": "CA", "volume": 12345678}, {"provider_state": "TX", "volume": 10234567}]}',
   'v1.0.0',
   CURRENT_TIMESTAMP(),
   'data_team@company.com'),

  ('Q002',
   'What is the average reimbursement for HCPCS code E1390?',
   'SELECT AVG(avg_allowed_amount) FROM ANALYTICS.FACT_DMEPOS_CLAIMS WHERE hcpcs_code = ''E1390''',
   '{"sample": [{"avg_reimbursement": 456.78}]}',
   'v1.0.0',
   CURRENT_TIMESTAMP(),
   'data_team@company.com');
```

> **✅ Reference:** See full implementation in [sql/intelligence/eval_seed.sql](../sql/intelligence/eval_seed.sql)

---

### Running Eval Seeds (Regression Testing)

**Automated test harness:**

```sql
CREATE TABLE INTELLIGENCE.EVAL_SEED_RESULTS (
  test_run_id STRING,
  question_id STRING,
  generated_sql TEXT,
  sql_matches_expected BOOLEAN,
  result_matches_expected BOOLEAN,
  execution_time_ms NUMBER,
  error_message STRING,
  test_timestamp TIMESTAMP
);

-- Run eval seeds (do this nightly or after semantic model changes)
INSERT INTO INTELLIGENCE.EVAL_SEED_RESULTS
SELECT
  UUID_STRING() AS test_run_id,
  q.question_id,
  -- Call Cortex Analyst with question
  ai_generated_sql AS generated_sql,
  (ai_generated_sql = q.expected_sql) AS sql_matches_expected,
  -- Compare results (fuzzy match, allow small diffs)
  (ai_result_sample = q.expected_result_sample) AS result_matches_expected,
  execution_time,
  error_msg,
  CURRENT_TIMESTAMP()
FROM INTELLIGENCE.EVAL_SEED_QUESTIONS q;
-- Note: Actual implementation requires calling Cortex Analyst API
```

**Pass/fail report:**

```sql
-- Eval seed pass rate
SELECT
  COUNT(*) AS total_tests,
  COUNT_IF(result_matches_expected) AS passed,
  COUNT_IF(NOT result_matches_expected) AS failed,
  (passed / total_tests * 100) AS pass_rate_pct
FROM INTELLIGENCE.EVAL_SEED_RESULTS
WHERE test_timestamp = (SELECT MAX(test_timestamp) FROM INTELLIGENCE.EVAL_SEED_RESULTS);
```

**Alert if pass rate drops:**
> ⚠️ Eval Seed Regression Detected
> Pass rate: 85% (down from 98% yesterday)
> Failed questions: Q003, Q007, Q012
> Action: Review recent semantic model changes, investigate failures

---

### Human Validation Framework

**Problem:** Eval seeds only cover known questions. What about new user questions?

**Solution: Thumbs up/down feedback**

```sql
CREATE TABLE INTELLIGENCE.HUMAN_VALIDATION_FEEDBACK (
  feedback_id STRING,
  query_id STRING,  -- Links to CORTEX_ANALYST_QUERY_LOG
  user_name STRING,
  question TEXT,
  generated_sql TEXT,
  was_helpful BOOLEAN,  -- Thumbs up/down
  feedback_text STRING,  -- Optional comments
  feedback_timestamp TIMESTAMP
);

-- User interface (in your app)
-- After AI answers a question:
-- [👍 Helpful] [👎 Not Helpful] [💬 Add Comment]

-- Insert feedback
INSERT INTO INTELLIGENCE.HUMAN_VALIDATION_FEEDBACK VALUES (
  UUID_STRING(),
  'query_12345',
  CURRENT_USER(),
  'What is the average reimbursement by state?',
  'SELECT state, AVG(amount) FROM fact GROUP BY state',
  FALSE,  -- Thumbs down
  'Results seem incorrect - CA should be higher',
  CURRENT_TIMESTAMP()
);
```

**Analyze feedback:**

```sql
-- Questions with low satisfaction
SELECT
  question,
  COUNT(*) AS total_feedback,
  COUNT_IF(was_helpful) AS helpful_count,
  COUNT_IF(NOT was_helpful) AS not_helpful_count,
  (helpful_count / total_feedback * 100) AS satisfaction_pct
FROM INTELLIGENCE.HUMAN_VALIDATION_FEEDBACK
GROUP BY question
HAVING total_feedback >= 5  -- Min 5 feedback entries
ORDER BY satisfaction_pct ASC
LIMIT 20;
```

**Action:**
- Questions with <50% satisfaction → investigate
- Add to eval seed if recurring
- Update semantic model descriptions

---

## Part 4: Model Evolution and Versioning

### The Problem: Changes Break Things

**Scenario:**
- Data team updates semantic model (adds new measure)
- Accidentally changes existing measure definition
- All historical queries return different results
- CEO freaks out (see intro)

**Solution: Version control**

---

### Semantic Model Versioning

**Best practice: Treat semantic models like code**

```bash
# Git repository structure
models/
├── DMEPOS_SEMANTIC_MODEL_v1.0.0.yaml
├── DMEPOS_SEMANTIC_MODEL_v1.1.0.yaml  # Current
└── CHANGELOG.md
```

**CHANGELOG.md:**
```markdown
# Semantic Model Changelog

## v1.1.0 (2024-01-15)
### Added
- New measure: `total_unique_providers` (count distinct provider NPIs)
- New dimension: `provider_credential` (MD, DO, NP, PA)

### Changed
- **BREAKING:** Renamed measure `total_payment` to `total_reimbursement` for clarity
- Updated description for `avg_allowed_amount` to specify USD currency

### Fixed
- Fixed synonym for `provider_state` (was missing "location")

## v1.0.0 (2024-01-01)
- Initial release
```

**Semantic versioning:**
- **Major version (1.x.x → 2.x.x):** Breaking changes (renamed/removed measures or dimensions)
- **Minor version (x.1.x → x.2.x):** Non-breaking additions (new measures, new dimensions)
- **Patch version (x.x.1 → x.x.2):** Bug fixes (typos, description updates)

---

### Tracking Model Versions in Snowflake

```sql
CREATE TABLE INTELLIGENCE.SEMANTIC_MODEL_VERSIONS (
  version STRING PRIMARY KEY,
  model_name STRING,
  git_commit_hash STRING,
  deployed_by STRING,
  deployed_at TIMESTAMP,
  is_active BOOLEAN,
  changelog TEXT
);

-- Deploy new version
INSERT INTO INTELLIGENCE.SEMANTIC_MODEL_VERSIONS VALUES (
  'v1.1.0',
  'DMEPOS_ANALYST',
  'abc123def456',
  'data_engineer@company.com',
  CURRENT_TIMESTAMP(),
  TRUE,  -- Activate
  '## v1.1.0\n### Added\n- New measure: total_unique_providers\n### Changed\n- Renamed total_payment to total_reimbursement'
);

-- Deactivate old version
UPDATE INTELLIGENCE.SEMANTIC_MODEL_VERSIONS
SET is_active = FALSE
WHERE version = 'v1.0.0';
```

**Link queries to model versions:**

```sql
-- Update query log to track model version
ALTER TABLE INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG
ADD COLUMN semantic_model_version STRING;

-- Populate with current version
UPDATE INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG
SET semantic_model_version = (
  SELECT version
  FROM INTELLIGENCE.SEMANTIC_MODEL_VERSIONS
  WHERE is_active = TRUE
    AND model_name = 'DMEPOS_ANALYST'
)
WHERE semantic_model_version IS NULL;
```

**Now you can answer:** "Which version of the model generated this query?"

---

### Rollback Procedure

**When bad deployment happens:**

```sql
-- Step 1: Check current version
SELECT * FROM INTELLIGENCE.SEMANTIC_MODEL_VERSIONS
WHERE is_active = TRUE;

-- Step 2: Deactivate bad version
UPDATE INTELLIGENCE.SEMANTIC_MODEL_VERSIONS
SET is_active = FALSE
WHERE version = 'v1.1.0';

-- Step 3: Reactivate previous version
UPDATE INTELLIGENCE.SEMANTIC_MODEL_VERSIONS
SET is_active = TRUE
WHERE version = 'v1.0.0';

-- Step 4: Redeploy v1.0.0 YAML to Snowflake
-- (via SnowSQL or Snowsight)

-- Step 5: Run eval seeds to confirm rollback worked
-- (See Part 3: Evaluation Frameworks)
```

**Time to rollback:** <5 minutes (if you have this infrastructure)

---

### Deprecation Pattern

**Scenario:** You want to remove a measure, but users might still reference it.

**Bad approach:** Delete immediately → break all queries

**Good approach:** Deprecate gracefully

```yaml
# Semantic model with deprecation
measures:
  - name: total_payment
    deprecated: true
    deprecated_since: "v1.1.0"
    deprecated_reason: "Renamed to total_reimbursement for clarity"
    replacement: "total_reimbursement"
    synonyms:
      - total_reimbursement  # Map old name to new measure
    description: >
      DEPRECATED: Use total_reimbursement instead.
      This measure will be removed in v2.0.0.
    expr: SUM(total_allowed_amount)
```

**Deprecation timeline:**
- **v1.1.0:** Deprecate (still works, but warns)
- **v1.2.0:** Continue warning
- **v2.0.0:** Remove entirely (breaking change)

**Give users 2-3 versions to migrate.**

> **📋 Reference:** See comprehensive versioning guide in [Docs: Semantic Model Lifecycle](../docs/governance/semantic_model_lifecycle.md) and implementation in [sql/intelligence/semantic_model_tests.sql](../sql/intelligence/semantic_model_tests.sql)

---

## Part 5: Feedback Loops and Continuous Improvement

### The Virtuous Cycle

```
┌─────────────────────────────────────────────────┐
│          1. USER ASKS QUESTION                  │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│       2. AI GENERATES SQL & RETURNS RESULT      │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│        3. USER PROVIDES FEEDBACK                │
│        (Thumbs up/down, comments)               │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│      4. DATA TEAM REVIEWS LOW-RATED QUERIES     │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│     5. UPDATE SEMANTIC MODEL (descriptions,     │
│        synonyms, verified queries)              │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│       6. RUN EVAL SEEDS (regression test)       │
└─────────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│         7. DEPLOY NEW VERSION                   │
└─────────────────────────────────────────────────┘
                     │
                     └──────► (Back to Step 1)
```

**This is continuous improvement.**

---

### Weekly Review Process

**Every Monday, data team reviews:**

1. **Low-rated queries** (from human feedback)
2. **Failed eval seeds** (from nightly tests)
3. **Data quality issues** (from profiling)
4. **Semantic drift** (from distribution changes)

**Template for review meeting:**

```sql
-- 1. Low-rated queries (satisfaction < 50%)
SELECT
  question,
  COUNT(*) AS feedback_count,
  ROUND(AVG(CASE WHEN was_helpful THEN 1 ELSE 0 END) * 100, 2) AS satisfaction_pct,
  LISTAGG(DISTINCT feedback_text, '; ') AS user_comments
FROM INTELLIGENCE.HUMAN_VALIDATION_FEEDBACK
WHERE feedback_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY question
HAVING satisfaction_pct < 50
ORDER BY feedback_count DESC;

-- 2. Failed eval seeds
SELECT
  question_id,
  question_text,
  error_message
FROM INTELLIGENCE.EVAL_SEED_RESULTS r
JOIN INTELLIGENCE.EVAL_SEED_QUESTIONS q ON r.question_id = q.question_id
WHERE test_timestamp = (SELECT MAX(test_timestamp) FROM INTELLIGENCE.EVAL_SEED_RESULTS)
  AND NOT result_matches_expected;

-- 3. Data quality issues (from profiling)
SELECT
  table_name,
  column_name,
  issue_type,
  issue_description
FROM GOVERNANCE.QUALITY_ISSUES
WHERE discovered_at > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND resolved_at IS NULL
ORDER BY severity DESC;

-- 4. Semantic drift alerts
SELECT
  table_name,
  column_name,
  baseline_avg,
  current_avg,
  pct_change
FROM GOVERNANCE.DRIFT_ALERTS
WHERE alert_date > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY ABS(pct_change) DESC;
```

> **📋 Reference:** See the complete weekly review framework in [Docs: Human Validation Log](../docs/governance/human_validation_log.md) and [sql/intelligence/validation_framework.sql](../sql/intelligence/validation_framework.sql)

**Action items from review:**
- Update semantic model descriptions
- Add new synonyms
- Create new verified queries (eval seeds)
- Fix data quality issues
- Retrain/update embeddings

---

### Automating the Feedback Loop

**Automated actions (run nightly):**

```sql
-- Auto-add frequently asked questions to eval seeds
INSERT INTO INTELLIGENCE.EVAL_SEED_QUESTIONS
SELECT
  UUID_STRING() AS question_id,
  question AS question_text,
  generated_sql AS expected_sql,
  result_sample AS expected_result_sample,
  semantic_model_version,
  CURRENT_TIMESTAMP() AS created_at,
  'automation' AS created_by
FROM (
  SELECT
    question,
    generated_sql,
    result_sample,
    semantic_model_version,
    COUNT(*) AS ask_count,
    AVG(CASE WHEN was_helpful THEN 1 ELSE 0 END) AS satisfaction
  FROM INTELLIGENCE.CORTEX_ANALYST_QUERY_LOG l
  LEFT JOIN INTELLIGENCE.HUMAN_VALIDATION_FEEDBACK f ON l.query_id = f.query_id
  WHERE l.query_timestamp > DATEADD(day, -30, CURRENT_TIMESTAMP())
  GROUP BY question, generated_sql, result_sample, semantic_model_version
  HAVING ask_count >= 10  -- Asked at least 10 times
    AND satisfaction > 0.8  -- High satisfaction
)
WHERE question NOT IN (SELECT question_text FROM INTELLIGENCE.EVAL_SEED_QUESTIONS);
```

**Result:** Popular, high-quality questions automatically become regression tests.

---

## Best Practices Summary

### AI Governance
- ✅ Build a comprehensive metadata catalog (business + governance attributes)
- ✅ Track table lineage (impact analysis for changes)
- ✅ Implement row-level and column-level security
- ✅ Log all AI queries (who, what, when)
- ✅ Mark PII/PHI columns, apply masking policies

### Data Quality
- ✅ Profile data weekly (row counts, null rates, distributions)
- ✅ Detect semantic drift (compare current vs baseline)
- ✅ Check embedding staleness (text changed → recompute embeddings)
- ✅ Validate referential integrity (foreign keys point to real rows)
- ✅ Automate quality checks, alert on failures

### Evaluation
- ✅ Create eval seeds (golden questions + expected SQL + results)
- ✅ Run nightly regression tests
- ✅ Collect human feedback (thumbs up/down)
- ✅ Review low-rated queries weekly
- ✅ Auto-promote popular queries to eval seeds

### Model Evolution
- ✅ Version semantic models (Git + semantic versioning)
- ✅ Track deployed versions in Snowflake
- ✅ Link queries to model versions (which version generated this answer?)
- ✅ Maintain changelog (added, changed, deprecated)
- ✅ Implement rollback procedure (<5 min to revert)
- ✅ Deprecate gracefully (2-3 versions before removal)

### Feedback Loops
- ✅ Weekly review: low-rated queries, failed seeds, quality issues, drift
- ✅ Update semantic model based on feedback
- ✅ Re-run eval seeds after changes
- ✅ Deploy new version (Git → Snowflake)
- ✅ Monitor satisfaction trends

---

## Common Pitfalls

### Pitfall 1: No Audit Logs

**Mistake:** "We don't need to log queries, it's just internal use"

**Reality:** Compliance audit, CEO asks "who accessed this sensitive data?"

**Fix:** Log everything. Disk is cheap, lawsuits are expensive.

---

### Pitfall 2: No Eval Seeds

**Mistake:** "We'll test manually before deploying"

**Reality:** Manual testing misses edge cases, regression happens

**Fix:** 20 eval seeds = 80% coverage. Automate.

---

### Pitfall 3: No Versioning

**Mistake:** "We'll just update the model in place"

**Reality:** Change breaks queries, can't rollback, CEO angry

**Fix:** Git + semantic versioning + changelog. Always.

---

### Pitfall 4: Ignoring Feedback

**Mistake:** "Users gave thumbs down, but we're too busy to investigate"

**Reality:** Satisfaction drops, users stop using AI, project fails

**Fix:** Weekly review is non-negotiable. 1 hour/week prevents disasters.

---

## Conclusion: You're Now Production-Ready

You've learned:

✅ **AI Governance** (metadata, lineage, access control, audit logs)
✅ **Data Quality for AI** (profiling, drift detection, embedding staleness)
✅ **Evaluation Frameworks** (eval seeds, regression tests, human feedback)
✅ **Model Evolution** (versioning, change management, rollback)
✅ **Feedback Loops** (continuous improvement, weekly reviews)

**The Trust Layer is complete.**

Now you can sleep at night knowing:
- Your AI is auditable
- Changes won't break production
- Quality issues are detected automatically
- Users can provide feedback
- The system improves over time

**This is production AI done right.**

---

## What's Next

**Continue the series:**

🧠 **[Part 1: The Intelligence Layer](#)**
How to build semantic models, design search corpuses, and implement embeddings.

🏗️ **[Part 2: The Foundation Layer](#)**
Data architecture patterns for AI: medallion design, schema organization, and optimization.

🎯 **[Hub Article: The Complete Guide](#)**
Overview of all three layers and the roadmap to production.

---

## Resources

**GitHub Repository:**
[Snowflake Intelligence Medicare Demo](https://github.com/YOUR_USERNAME/snowflake-intelligence-medicare-pos-analyst)

**Official Documentation:**
- [Snowflake Governance](https://docs.snowflake.com/en/user-guide/governance)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row)
- [Masking Policies](https://docs.snowflake.com/en/user-guide/security-column)

---

## Let's Talk

**Built a production AI system? Share your war stories.**

**Have governance horror stories? We want to hear them.**

**Found this helpful?**
- ⭐ Star the [GitHub repo](#)
- 🔗 Share on LinkedIn
- 💬 Leave a comment

---

**Series complete!** You now have everything you need to build a production-ready Snowflake Intelligence platform.

*Now go build something trustworthy. Your CEO will thank you.* 🛡️
