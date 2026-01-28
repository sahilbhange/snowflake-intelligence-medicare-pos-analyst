# The Intelligence Layer: How AI Understands and Finds Your Data

*Or: Teaching Machines to Read Your Mind (Sort Of)*

---

**Part of the series:** [The Complete Guide to Snowflake Intelligence](#) (Hub Article)

**Navigation:**
- 🧠 **Part 1: The Intelligence Layer** (You are here)
- 🏗️ [Part 2: The Foundation Layer](#) - Architecture and data engineering
- 🛡️ [Part 3: The Trust Layer](#) - Governance and production readiness

---

## The AI That Couldn't

Meet Alex. Smart guy. Built a beautiful data warehouse. Star schema, properly normalized, clustered to perfection. Spent 6 months on it.

Then his company bought Snowflake Intelligence.

**Day 1:** Alex creates a semantic model. Points it at his tables. Deploys.

**Day 2:** CEO asks Cortex Analyst: "What were our top products last quarter?"

**AI response:** "I found a table called SALES_FACT with a column called PROD_ID. However, I cannot determine what constitutes 'top' products or identify the relevant time period."

CEO: "This is useless."

Alex: *confused face*

**The problem?** Alex's data warehouse was built for humans who know that:
- `PROD_ID` = Product Identifier
- "Top" means highest revenue
- "Last quarter" means Q4 2023
- SALES_FACT has a `SALE_DT` column for filtering

**The AI doesn't know any of this.**

Three weeks later, after adding:
- Column descriptions with business context
- A semantic model defining "revenue" as a measure
- Time dimension metadata
- Verified queries showing examples

**Same question, new response:**
```sql
SELECT
  p.product_name,
  SUM(f.revenue) as total_revenue
FROM sales_fact f
JOIN dim_product p ON f.prod_id = p.product_id
WHERE f.sale_dt >= '2023-10-01' AND f.sale_dt < '2024-01-01'
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 10;
```

CEO: "Wow, this is amazing!"

Alex: *relieved face*

**The difference?** Context. Semantics. Metadata.

This is the Intelligence Layer.


---

## 📍 You Are Here

This is a **concept deep dive** (20-22 min read). For quick reference and code:

| Want This | See This |
|-----------|----------|
| Quick parameter lookup | [📚 Docs: Embedding Strategy](../../docs/reference/embedding_strategy.md) |
| Agent configuration reference | [📚 Docs: Cortex Agent Creation](../../docs/reference/cortex_agent_creation.md) |
| Working code to copy-paste | [💾 SQL: sql/search/](../../sql/search/) and [sql/agent/](../../sql/agent/) |
| Full deployment guide | [📚 Docs: Getting Started](../../docs/implementation/getting-started.md) |

**Also useful:** Each SQL file has navigation comments linking back here. Each docs file links to this article for deeper learning.

---

---

## What You'll Learn

By the end of this deep dive, you'll know:

1. **Context Engineering** - Making data self-describing (metadata everywhere)
2. **Semantic Models** - Teaching AI your business logic (Cortex Analyst deep dive)
3. **Vector Search** - Finding things when structure isn't enough (Cortex Search)
4. **Embeddings & RAG** - Advanced retrieval patterns
5. **Knowledge Graphs** - Mapping relationships for AI (optional/advanced)
6. **Putting It All Together** - The complete intelligence stack

**Estimated reading time:** 22-25 minutes

**Code repository:** [GitHub - Snowflake Intelligence Medicare Demo](#)

Let's make your data intelligent.

---

## Part 1: Context Engineering - Making Data Self-Describing

### The Problem: Data Without Context

**Scenario:** Your table has these columns:
```
AMT
DT
CD
STS
```

**Human analyst:** *Knows from tribal knowledge that:*
- `AMT` = Reimbursement amount in USD
- `DT` = Service date (not claim date)
- `CD` = HCPCS procedure code
- `STS` = Claim status (P=Pending, A=Approved, D=Denied)

**AI:** *Sees:*
- `AMT` = Could be anything. Amount? Amplitude? Amortization?
- `DT` = Date. But of what? Birth? Death? Transaction? Expiration?
- `CD` = Code. But which kind? Zip? Product? Error?
- `STS` = No idea. Statistics? Status? Something else?

**The AI generates garbage queries because it has zero context.**

---

### The Solution: Context Engineering

**Context Engineering** = Making every piece of data explain itself.

This includes:

1. **Descriptive metadata** - What does this column mean?
2. **Temporal context** - When is this data valid?
3. **Relational context** - How does this connect to other data?
4. **Business context** - What rules apply?

Let's build each layer.

---

### Layer 1: Descriptive Metadata

> **🔗 Reference:** [docs/reference/embedding_strategy.md](../../docs/reference/embedding_strategy.md)

**💾 Code:** [sql/search/cortex_search_hcpcs.sql](../../sql/search/cortex_search_hcpcs.sql)


**Before:**
```sql
CREATE TABLE fact_claims (
  amt FLOAT,
  dt DATE,
  cd STRING,
  sts STRING
);
```

**After:**
```sql
CREATE TABLE fact_claims (
  amt FLOAT COMMENT 'Total Medicare-allowed reimbursement amount in USD. Includes patient responsibility and plan payment.',
  dt DATE COMMENT 'Service date when the medical service was rendered. Format: YYYY-MM-DD. Not the same as claim submission date.',
  cd STRING COMMENT 'HCPCS (Healthcare Common Procedure Coding System) code identifying the medical procedure, equipment, or supply. Format: 1 letter + 4 digits (e.g., E1390).',
  sts STRING COMMENT 'Claim processing status. Valid values: P (Pending review), A (Approved and paid), D (Denied), R (Requires additional information). Default: P.'
);
```

**Now AI knows:**
- What each column means
- What values are valid
- What format to expect
- What the column is NOT (e.g., service date ≠ claim date)

---

### Creating a Metadata Catalog

**Don't just rely on SQL comments.** Build a governance table.

```sql
-- GOVERNANCE.COLUMN_METADATA
CREATE TABLE GOVERNANCE.COLUMN_METADATA (
  schema_name STRING,
  table_name STRING,
  column_name STRING,
  business_name STRING,           -- Human-friendly name
  data_type STRING,
  business_definition STRING,      -- Detailed explanation
  valid_values STRING,             -- Enumerated list or pattern
  example_values STRING,           -- Real examples
  is_pii BOOLEAN,                  -- Sensitive data flag
  owner STRING,                    -- Who maintains this
  last_updated TIMESTAMP
);

-- Example row
INSERT INTO GOVERNANCE.COLUMN_METADATA VALUES (
  'ANALYTICS',
  'FACT_DMEPOS_CLAIMS',
  'avg_allowed_amount',
  'Average Medicare Reimbursement',
  'FLOAT',
  'Average Medicare-allowed reimbursement amount per service in USD. Calculated as total_allowed_amount / total_services. Includes both patient responsibility and Medicare payment portions.',
  'Range: $0.01 to $50,000. Typical: $50-500 for DME supplies, $1,000-5,000 for equipment.',
  '[$45.23, $156.78, $2,340.50]',
  FALSE,
  'data_governance_team@company.com',
  CURRENT_TIMESTAMP()
);
```

> **Full code:** [sql/setup/20_setup_grants.sql](../../sql/setup/)


**Now you have a queryable catalog that:**
- ✅ AI can read (include this in semantic model context)
- ✅ Humans can search ("show me all PII columns")
- ✅ Governance can audit
- ✅ Lineage can reference

---

### Layer 2: Temporal Context

**The problem:** Data changes over time. How does AI know when this row is valid?

**Bad table design:**
```sql
-- No temporal context
SELECT * FROM dim_provider;
-- Which version of Dr. Smith? Current? Historical?
```

**Good table design (Slowly Changing Dimension Type 2):**
```sql
CREATE TABLE dim_provider (
  provider_npi STRING,
  provider_name STRING,
  provider_specialty STRING,

  -- Temporal context
  valid_from DATE COMMENT 'Date when this provider record became active',
  valid_to DATE COMMENT 'Date when this provider record was superseded. NULL = current record',
  is_current BOOLEAN COMMENT 'TRUE if this is the active version of the provider',

  -- Audit context
  loaded_at TIMESTAMP COMMENT 'When this row was inserted into the warehouse',
  updated_at TIMESTAMP COMMENT 'When this row was last modified'
);

-- Query for current state
SELECT * FROM dim_provider WHERE is_current = TRUE;

-- Query for historical state
SELECT * FROM dim_provider
WHERE '2022-01-01' BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31');
```

**Now AI can:**
- Get current state (default)
- Time-travel to historical states
- Understand data freshness (`loaded_at`, `updated_at`)

---

### Layer 3: Relational Context

**The problem:** AI doesn't know how tables relate.

**Bad documentation:**
```sql
-- Fact table has provider_npi
-- Dim table has provider_npi
-- Good luck figuring out the join!
```

**Good documentation (Foreign Key + Metadata):**
```sql
-- Define foreign keys (even if not enforced)
ALTER TABLE fact_dmepos_claims
ADD CONSTRAINT fk_provider
FOREIGN KEY (provider_npi) REFERENCES dim_provider(provider_npi)
NOT ENFORCED;  -- Snowflake doesn't enforce, but documents relationship

-- Also document in metadata catalog
CREATE TABLE GOVERNANCE.TABLE_RELATIONSHIPS (
  parent_table STRING,
  parent_column STRING,
  child_table STRING,
  child_column STRING,
  relationship_type STRING,  -- ONE_TO_MANY, MANY_TO_ONE, MANY_TO_MANY
  business_description STRING
);

INSERT INTO GOVERNANCE.TABLE_RELATIONSHIPS VALUES (
  'DIM_PROVIDER',
  'provider_npi',
  'FACT_DMEPOS_CLAIMS',
  'provider_npi',
  'ONE_TO_MANY',
  'One provider can have many claims. Each claim is associated with exactly one provider.'
);
```

**Now AI knows:**
- Which tables connect
- Which columns to join on
- Cardinality (1:N, N:1, N:M)
- Business meaning of the relationship

---

### Layer 4: Business Context

**Example: Business rules that aren't in the data**

```sql
CREATE TABLE GOVERNANCE.BUSINESS_RULES (
  rule_id STRING,
  applies_to_table STRING,
  rule_description STRING,
  rule_sql STRING,  -- Validation query
  severity STRING   -- WARNING, ERROR, CRITICAL
);

INSERT INTO GOVERNANCE.BUSINESS_RULES VALUES (
  'BR001',
  'FACT_DMEPOS_CLAIMS',
  'Total allowed amount cannot exceed $50,000 per claim. Claims above this threshold require manual review.',
  'SELECT * FROM FACT_DMEPOS_CLAIMS WHERE total_allowed_amount > 50000',
  'WARNING'
);
```

**Use case:** When AI generates a query that filters claims > $50k, it can warn:
> "Note: Claims above $50,000 require manual review and may not reflect typical patterns."

---

### Real-World Example: Medicare Demo Metadata

```sql
-- From: sql/governance/metadata_and_quality.sql

CREATE OR REPLACE TABLE GOVERNANCE.COLUMN_METADATA (
  schema_name STRING,
  table_name STRING,
  column_name STRING,
  business_name STRING,
  business_definition STRING,
  data_type STRING,
  is_pii BOOLEAN,
  sample_values STRING
);

-- Provider NPI
INSERT INTO GOVERNANCE.COLUMN_METADATA VALUES (
  'ANALYTICS',
  'DIM_PROVIDER',
  'provider_npi',
  'Provider National Provider Identifier',
  'Unique 10-digit identifier assigned by CMS to healthcare providers. Used to track providers across claims. Format: 10 numeric digits.',
  'STRING(10)',
  TRUE,  -- PII
  '["1234567890", "9876543210"]'
);

-- HCPCS Code
INSERT INTO GOVERNANCE.COLUMN_METADATA VALUES (
  'ANALYTICS',
  'FACT_DMEPOS_CLAIMS',
  'hcpcs_code',
  'HCPCS Procedure Code',
  'Healthcare Common Procedure Coding System code identifying medical services, equipment, and supplies. Level II codes for DME are format: 1 letter (A-V) + 4 digits. Example: E1390 = Oxygen concentrator.',
  'STRING(5)',
  FALSE,
  '["E1390", "E1391", "A4244"]'
);
```

**[GitHub Gist: Full metadata catalog schema](#)**

---

## Part 2: Semantic Models - Teaching AI Your Business Logic

> **Want the quick reference?** Jump to [docs/reference/cortex_agent_creation.md](../../docs/reference/cortex_agent_creation.md) for config tables and parameters.


### What Is a Semantic Model?

**In human terms:** A semantic model is like giving AI a guidebook to your data warehouse.

**In technical terms:** A YAML file that defines:
- **Tables** - Where your data lives
- **Measures** - Numbers you aggregate (SUM, AVG, COUNT)
- **Dimensions** - Things you slice by (state, year, product)
- **Filters** - Valid ways to narrow data
- **Verified queries** - Example questions with known-good SQL

**Cortex Analyst uses this guidebook to translate natural language → SQL.**

---

### Anatomy of a Semantic Model

```yaml
# High-level structure
name: "DMEPOS Claims Analyst"
tables:
  - name: fact_dmepos_claims
    base_table: ANALYTICS.FACT_DMEPOS_CLAIMS
    dimensions: [...]
    measures: [...]
    filters: [...]

relationships:
  - left: fact_dmepos_claims
    right: dim_provider
    on: provider_npi

verified_queries:
  - question: "Top 10 states by claim volume"
    sql: "SELECT state, SUM(total_services)..."
```

Let's build each section.

---

### Section 1: Tables

**Define the tables AI can query:**

```yaml
tables:
  - name: fact_dmepos_claims
    description: >
      Medicare Part B claims for durable medical equipment (DME), prosthetics,
      orthotics, and supplies (DMEPOS). Grain: One row per provider, HCPCS code, and year.
      Contains measures for patient counts, service volumes, and reimbursement amounts.
    base_table:
      database: MEDICARE_POS_DB
      schema: ANALYTICS
      table: FACT_DMEPOS_CLAIMS
```

**Key principles:**
- ✅ **Describe grain** ("One row per X, Y, Z")
- ✅ **Explain purpose** (What business questions does this answer?)
- ✅ **Be explicit** (Don't assume AI knows acronyms like "DME" or "HCPCS")

---

### Section 2: Dimensions

**Dimensions = Things you slice by**

```yaml
dimensions:
  - name: provider_npi
    synonyms:
      - provider
      - doctor
      - practitioner
      - NPI
    description: >
      National Provider Identifier - unique 10-digit ID for healthcare providers.
      Use this to identify individual providers or count distinct providers.
    expr: provider_npi
    data_type: TEXT
    unique: true

  - name: provider_state
    synonyms:
      - state
      - location
      - geography
    description: >
      Two-letter US state code where the provider practices (e.g., CA, NY, TX).
      Use this to analyze geographic patterns in claims.
    expr: provider_state
    data_type: TEXT
    sample_values:
      - "CA"
      - "NY"
      - "TX"
      - "FL"

  - name: year
    synonyms:
      - calendar year
      - service year
    description: >
      Year when the service was rendered. Note: This is service year, not
      claim submission year. Use for time-series analysis.
    expr: year
    data_type: NUMBER
```

**Key principles:**
- ✅ **Add synonyms** (AI should understand "state" = "location" = "geography")
- ✅ **Clarify ambiguity** (Service year ≠ claim year)
- ✅ **Provide samples** (Helps AI understand valid values)

---

### Section 3: Measures

**Measures = Numbers you aggregate**

```yaml
measures:
  - name: total_beneficiaries
    synonyms:
      - patient count
      - number of patients
      - beneficiary count
    description: >
      Count of unique Medicare beneficiaries who received services. Use this to
      measure patient volume. Note: Same patient can be counted in multiple rows
      if they received services from different providers or for different procedures.
    expr: SUM(total_beneficiaries)
    data_type: NUMBER
    default_aggregation: sum

  - name: total_services
    synonyms:
      - service count
      - number of services
      - claim volume
    description: >
      Total count of services rendered. One service = one line item on a claim.
      Use this to measure volume of care delivered.
    expr: SUM(total_services)
    data_type: NUMBER
    default_aggregation: sum

  - name: average_reimbursement
    synonyms:
      - avg reimbursement
      - average payment
      - avg allowed amount
    description: >
      Average Medicare-allowed reimbursement per service in USD. Calculated as
      total_allowed_amount divided by total_services. Use this to analyze cost
      per service.
    expr: AVG(avg_allowed_amount)
    data_type: NUMBER
    default_aggregation: avg

  - name: total_reimbursement
    synonyms:
      - total payment
      - total cost
      - total allowed amount
    description: >
      Total Medicare-allowed reimbursement across all services in USD. This is
      the sum of all payments (plan + patient responsibility). Use this to
      measure total spend.
    expr: SUM(total_allowed_amount)
    data_type: NUMBER
    default_aggregation: sum
```

**Key principles:**
- ✅ **Specify aggregation** (SUM, AVG, COUNT, MIN, MAX)
- ✅ **Explain calculation** (How is this derived?)
- ✅ **Provide context** (When should users choose this measure?)

---

### Section 4: Filters

**Filters = Valid ways to narrow data**

```yaml
filters:
  - name: recent_years
    description: "Filter to recent years (2020 and later)"
    expr: year >= 2020

  - name: high_volume_providers
    description: "Providers with at least 100 patients"
    expr: total_beneficiaries >= 100

  - name: expensive_services
    description: "Services with average reimbursement above $1,000"
    expr: avg_allowed_amount > 1000
```

**Use case:**
- User: "Show me high-volume providers in recent years"
- AI applies: `WHERE year >= 2020 AND total_beneficiaries >= 100`

---

### Section 5: Relationships

**How tables connect:**

```yaml
relationships:
  - name: provider_details
    left_table: fact_dmepos_claims
    left_column: provider_npi
    right_table: dim_provider
    right_column: provider_npi
    relationship_type: many_to_one
    description: >
      Join to get provider details (name, specialty, city, state).
      Each claim row corresponds to one provider.

  - name: device_details
    left_table: fact_dmepos_claims
    left_column: hcpcs_code
    right_table: dim_device
    right_column: hcpcs_code
    relationship_type: many_to_one
    description: >
      Join to get device information (brand name, manufacturer, description).
      Each HCPCS code maps to device catalog entries.
```

**AI uses this to automatically generate joins.**

---

### Section 6: Verified Queries

**Golden questions with known-good SQL:**

```yaml
verified_queries:
  - name: top_states_by_volume
    question: "What are the top 10 states by total claim volume?"
    verified_at: "2024-01-15"
    verified_by: "data_team@company.com"
    sql: |
      SELECT
        provider_state,
        SUM(total_services) as service_count
      FROM ANALYTICS.FACT_DMEPOS_CLAIMS
      GROUP BY provider_state
      ORDER BY service_count DESC
      LIMIT 10;

  - name: avg_reimbursement_by_state
    question: "What is the average reimbursement per service by state?"
    verified_at: "2024-01-15"
    verified_by: "data_team@company.com"
    sql: |
      SELECT
        provider_state,
        AVG(avg_allowed_amount) as avg_reimbursement
      FROM ANALYTICS.FACT_DMEPOS_CLAIMS
      GROUP BY provider_state
      ORDER BY avg_reimbursement DESC;
```

**Why verified queries matter:**
1. **Regression testing** - Run these periodically to ensure semantic model still works
2. **Training examples** - AI learns patterns from these queries
3. **Documentation** - Shows users what questions are answerable

---

### Complete Semantic Model Example

```yaml
# models/DMEPOS_SEMANTIC_MODEL.yaml
name: DMEPOS_Claims_Analyst
description: >
  Semantic model for analyzing Medicare Part B DMEPOS claims. Supports
  questions about provider patterns, geographic trends, device utilization,
  and reimbursement analysis.

tables:
  - name: fact_dmepos_claims
    description: >
      Medicare Part B claims for durable medical equipment (DME), prosthetics,
      orthotics, and supplies. Grain: provider × HCPCS code × year.
    base_table:
      database: MEDICARE_POS_DB
      schema: ANALYTICS
      table: FACT_DMEPOS_CLAIMS

    dimensions:
      - name: provider_npi
        synonyms: [provider, doctor, NPI]
        description: National Provider Identifier (unique provider ID)
        expr: provider_npi
        data_type: TEXT
        unique: true

      - name: hcpcs_code
        synonyms: [procedure code, service code]
        description: HCPCS code identifying medical equipment or supplies
        expr: hcpcs_code
        data_type: TEXT

      - name: year
        synonyms: [calendar year, service year]
        description: Year when service was rendered
        expr: year
        data_type: NUMBER

    measures:
      - name: total_beneficiaries
        synonyms: [patient count, beneficiary count]
        description: Count of unique Medicare patients
        expr: SUM(total_beneficiaries)
        data_type: NUMBER

      - name: total_services
        synonyms: [service count, claim volume]
        description: Total number of services rendered
        expr: SUM(total_services)
        data_type: NUMBER

      - name: total_reimbursement
        synonyms: [total payment, total cost]
        description: Total Medicare-allowed reimbursement in USD
        expr: SUM(total_allowed_amount)
        data_type: NUMBER

relationships:
  - name: provider_details
    left_table: fact_dmepos_claims
    left_column: provider_npi
    right_table: dim_provider
    right_column: provider_npi
    relationship_type: many_to_one

verified_queries:
  - name: top_states
    question: "Top 10 states by claim volume"
    sql: |
      SELECT provider_state, SUM(total_services) as volume
      FROM ANALYTICS.FACT_DMEPOS_CLAIMS
      GROUP BY provider_state
      ORDER BY volume DESC
      LIMIT 10;
```

**[GitHub Gist: Full semantic model YAML](#)**

---

### Testing Your Semantic Model

**Don't deploy blind. Test first.**

```sql
-- Test verified queries
SELECT * FROM TABLE(
  SNOWFLAKE.CORTEX.ANALYST_QUERY(
    'DMEPOS_SEMANTIC_MODEL',
    'What are the top 10 states by claim volume?'
  )
);

-- Compare AI result to verified query
-- Should match exactly
```

**If they don't match:**
1. Check dimension/measure definitions
2. Check synonyms (did AI misunderstand the question?)
3. Check relationships (did AI join wrong tables?)
4. Add more context to descriptions

---

## Part 3: Cortex Search - When Structure Isn't Enough

### The Problem Cortex Analyst Can't Solve

**Scenario 1:** User asks, "Find oxygen concentrators"

**Your data:**
```
HCPCS_CODE | HCPCS_DESCRIPTION
-----------+--------------------------------------------------
E1390      | Oxygen concentrator, single delivery port
E1391      | Oxygen concentrator, dual delivery port
E1392      | Portable oxygen concentrator, rental
```

**Cortex Analyst query:**
```sql
SELECT * FROM DIM_HCPCS
WHERE hcpcs_description ILIKE '%oxygen concentrator%';
```

**This works!** Structured keyword match.

---

**Scenario 2:** User asks, "Find devices for breathing problems"

**Your data:**
```
DEVICE_DESCRIPTION
--------------------------------------------------------------
Portable oxygen concentrator with pulse dose delivery
CPAP machine for sleep apnea treatment
Nebulizer for respiratory medication delivery
Ventilator for assisted breathing
```

**Cortex Analyst query:**
```sql
SELECT * FROM DIM_DEVICE
WHERE device_description ILIKE '%breathing problems%';
```

**This returns zero results.** Why?

The phrase "breathing problems" doesn't appear in descriptions. But semantically:
- "Oxygen concentrator" helps with breathing problems
- "CPAP" treats breathing problems (sleep apnea)
- "Nebulizer" treats breathing problems (asthma, COPD)
- "Ventilator" definitely helps with breathing problems

**AI needs to understand meaning, not just match keywords.**

**Enter: Cortex Search.**

---

### What Is Cortex Search?

**Cortex Search** = Vector similarity search + keyword search (hybrid).

It indexes text columns and optionally creates embeddings (vector representations) to find semantically similar content.

**Example:**
```sql
-- Create search service
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  ON device_description
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    device_identifier,
    brand_name,
    device_description
  FROM ANALYTICS.DIM_DEVICE
);

-- Search for "breathing problems"
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC(
    'breathing problems',
    {'limit': 10}
  )
);
```

> **Production example:** [sql/search/cortex_search_hcpcs.sql](../../sql/search/cortex_search_hcpcs.sql)


**Results:**
```
DEVICE_IDENTIFIER | BRAND_NAME        | DEVICE_DESCRIPTION              | SCORE
------------------+-------------------+---------------------------------+-------
12345678          | Philips Respironics | Portable oxygen concentrator  | 0.89
23456789          | ResMed            | CPAP machine for sleep apnea   | 0.85
34567890          | Omron             | Nebulizer for medication       | 0.82
```

**It found semantically related devices even though "breathing problems" doesn't appear in text.**

---

### How Cortex Search Works

**Two search modes:**

1. **Keyword search** (default) - Traditional BM25 ranking
2. **Vector search** (with embeddings) - Semantic similarity

**Hybrid search = Best of both worlds**

```sql
-- Hybrid search (keywords + vectors)
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  ON device_description
  ATTRIBUTES brand_name, company_name  -- Metadata to return
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    device_identifier,
    device_description,
    brand_name,
    company_name
  FROM ANALYTICS.DIM_DEVICE
);
```

**When to use keyword vs vector:**
- **Keyword:** Exact matches, product codes, technical terms
- **Vector:** Semantic queries, synonyms, related concepts
- **Hybrid:** Both (recommended for most use cases)

---

### Building Search Corpuses: Best Practices

#### Corpus 1: HCPCS Codes (Medical Procedures)

**Goal:** Let users search for procedures by description

```sql
CREATE CORTEX SEARCH SERVICE SEARCH.HCPCS_SEARCH_SVC
  ON hcpcs_description
  ATTRIBUTES hcpcs_code, hcpcs_category
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    hcpcs_code,
    hcpcs_description,
    hcpcs_category
  FROM ANALYTICS.DIM_HCPCS
);
```

**Sample queries:**
- "wheelchair" → Returns all wheelchair-related HCPCS codes
- "diabetes supplies" → Returns glucose monitors, test strips, insulin pumps
- "E1390" → Returns exact HCPCS code (keyword match)

---

#### Corpus 2: Medical Devices (FDA GUDID)

**Goal:** Let users search device catalog by description

```sql
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC
  ON device_description
  ATTRIBUTES device_identifier, brand_name, company_name
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    device_identifier,
    brand_name || ' - ' || device_description AS device_description,
    brand_name,
    company_name
  FROM ANALYTICS.DIM_DEVICE
  WHERE device_description IS NOT NULL
);
```

**Design decision:** Concatenate brand + description for richer search

**Sample queries:**
- "Medtronic insulin pump" → Brand + device type
- "portable oxygen" → Finds all portable oxygen devices
- "cardiac pacemaker" → Semantic match for heart devices

---

#### Corpus 3: Providers (Healthcare Practitioners)

**Goal:** Find providers by specialty, location, or name

```sql
CREATE CORTEX SEARCH SERVICE SEARCH.PROVIDER_SEARCH_SVC
  ON search_text
  ATTRIBUTES provider_npi, provider_name, provider_specialty, provider_state
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    provider_npi,
    provider_name,
    provider_specialty,
    provider_state,
    -- Combine multiple fields for rich search
    provider_name || ' ' ||
    provider_specialty || ' ' ||
    provider_city || ' ' ||
    provider_state AS search_text
  FROM ANALYTICS.DIM_PROVIDER
);
```

**Sample queries:**
- "endocrinologist California" → Specialty + location
- "Dr. Smith" → Name search
- "family practice New York" → Specialty + state

---

### Hybrid Search Routing Pattern

**Problem:** User asks a question. Should you use Cortex Analyst or Cortex Search?

**Decision tree:**

```
User question
     │
     ├─ Aggregation needed? (SUM, AVG, COUNT, top N)
     │  └─ Use Cortex Analyst
     │
     ├─ Lookup by description? (Find X, Search for Y)
     │  └─ Use Cortex Search
     │
     └─ Both? (Find X and show total cost)
        └─ Use Cortex Search → get IDs → Use Cortex Analyst with filter
```

**Example: Hybrid query**

**User:** "What's the total spend on oxygen concentrators?"

**Step 1: Search for oxygen concentrators (Cortex Search)**
```sql
SELECT device_identifier, hcpcs_code
FROM TABLE(SEARCH.DEVICE_SEARCH_SVC('oxygen concentrator'))
LIMIT 10;
```

**Result:** `['E1390', 'E1391', 'E1392']`

**Step 2: Aggregate spend (Cortex Analyst)**
```sql
SELECT
  SUM(total_allowed_amount) as total_spend
FROM ANALYTICS.FACT_DMEPOS_CLAIMS
WHERE hcpcs_code IN ('E1390', 'E1391', 'E1392');
```

**Result:** $12,450,678

**This is the power of hybrid intelligence.**

---

## Part 4: Embeddings & RAG Patterns

### What Are Embeddings?

**Embedding** = Converting text into a vector of numbers that captures meaning.

**Example:**
```python
"oxygen concentrator" → [0.2, -0.5, 0.8, ..., 0.3]  # 768 dimensions
"breathing device"    → [0.19, -0.48, 0.82, ..., 0.29]  # Similar vector!
"pizza topping"       → [-0.9, 0.6, -0.2, ..., 0.7]  # Very different vector
```

**Similarity = Cosine distance between vectors**

---

### Snowflake's Embedding Function

```sql
-- Generate embedding for text
SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
  'snowflake-arctic-embed-l',
  'portable oxygen concentrator'
) AS embedding;

-- Returns: VECTOR(1024, FLOAT)
```

> **Complete implementation:** [sql/search/cortex_search_pdf.sql](../../sql/search/cortex_search_pdf.sql)


**Embedding models available:**
- `snowflake-arctic-embed-m` (768 dimensions, fast)
- `snowflake-arctic-embed-l` (1024 dimensions, more accurate)

---

### Use Case 1: Semantic Search with Embeddings

**Problem:** Cortex Search keyword matching isn't finding good matches

**Solution:** Pre-compute embeddings, store them, search by vector similarity

```sql
-- Step 1: Add embedding column to table
ALTER TABLE ANALYTICS.DIM_DEVICE
ADD COLUMN device_description_embedding VECTOR(1024, FLOAT);

-- Step 2: Compute embeddings
UPDATE ANALYTICS.DIM_DEVICE
SET device_description_embedding = SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
  'snowflake-arctic-embed-l',
  device_description
)
WHERE device_description IS NOT NULL;

-- Step 3: Create Cortex Search service with embedding column
CREATE CORTEX SEARCH SERVICE SEARCH.DEVICE_SEARCH_SVC_ADVANCED
  ON device_description
  EMBEDDING device_description_embedding
  WAREHOUSE = medicare_pos_wh
  TARGET_LAG = '1 hour'
AS (
  SELECT
    device_identifier,
    device_description,
    device_description_embedding,
    brand_name,
    company_name
  FROM ANALYTICS.DIM_DEVICE
);

-- Step 4: Search (now uses vector similarity)
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC_ADVANCED(
    'devices for sleep apnea',
    {'limit': 10}
  )
);
```

**Result:** Better semantic matches (finds CPAP machines even if "sleep apnea" not in description)

---

### Use Case 2: RAG (Retrieval-Augmented Generation)

**RAG = Retrieve relevant context + Generate answer**

**Example: PDF document search**

**Problem:** You have 500 medical device manuals (PDFs). Users ask: "How do I clean the oxygen concentrator?"

**Traditional approach:** User reads 50-page manual

**RAG approach:**
1. **Ingest PDFs** → Extract text → Chunk into paragraphs
2. **Embed chunks** → Store in Snowflake with embeddings
3. **User asks question** → Embed question → Find similar chunks (vector search)
4. **Generate answer** → Pass chunks to LLM → Synthesize answer

**Implementation:**

```sql
-- Step 1: Document chunks table
CREATE TABLE GOVERNANCE.DOCUMENT_CHUNKS (
  chunk_id STRING,
  document_name STRING,
  page_number INT,
  chunk_text STRING,
  chunk_embedding VECTOR(1024, FLOAT)
);

-- Step 2: Ingest and embed
INSERT INTO GOVERNANCE.DOCUMENT_CHUNKS
SELECT
  UUID_STRING() AS chunk_id,
  'oxygen_concentrator_manual.pdf' AS document_name,
  page_number,
  chunk_text,
  SNOWFLAKE.CORTEX.EMBED_TEXT_1024('snowflake-arctic-embed-l', chunk_text) AS chunk_embedding
FROM extracted_pdf_chunks;

-- Step 3: Search for relevant chunks
WITH user_question AS (
  SELECT SNOWFLAKE.CORTEX.EMBED_TEXT_1024(
    'snowflake-arctic-embed-l',
    'How do I clean the oxygen concentrator?'
  ) AS question_embedding
),
similar_chunks AS (
  SELECT
    chunk_text,
    VECTOR_COSINE_SIMILARITY(chunk_embedding, user_question.question_embedding) AS similarity
  FROM GOVERNANCE.DOCUMENT_CHUNKS, user_question
  ORDER BY similarity DESC
  LIMIT 5
)
SELECT chunk_text FROM similar_chunks;
```

**Step 4: Pass chunks to LLM (Cortex Complete)**

```sql
SELECT SNOWFLAKE.CORTEX.COMPLETE(
  'mistral-large',
  ARRAY_CONSTRUCT(
    'Answer the following question based on the provided context.',
    'Question: How do I clean the oxygen concentrator?',
    'Context: ' || chunk_text_1,
    'Context: ' || chunk_text_2,
    'Context: ' || chunk_text_3
  )
) AS answer;
```

**Result:** AI-generated answer grounded in actual manual content

**[GitHub Gist: Complete RAG implementation](#)**

---

## Part 5: Knowledge Graphs (Advanced/Optional)

### Why Knowledge Graphs for AI?

**Traditional tables:**
- Provider prescribes HCPCS E1390
- HCPCS E1390 is an oxygen concentrator
- Oxygen concentrators treat respiratory conditions

**AI has to infer relationships from joins.**

**Knowledge graph:**
```
Provider ──prescribes──> Device ──treats──> Condition
                            │
                            └──manufactured_by──> Company
```

**AI can traverse relationships directly.**

---

### Building a Simple Knowledge Graph

**Entities table:**
```sql
CREATE TABLE INTELLIGENCE.KG_ENTITIES (
  entity_id STRING PRIMARY KEY,
  entity_type STRING,  -- PROVIDER, DEVICE, CONDITION, COMPANY
  entity_name STRING,
  properties VARIANT   -- JSON with additional attributes
);

-- Examples
INSERT INTO INTELLIGENCE.KG_ENTITIES VALUES
  ('PROV_123', 'PROVIDER', 'Dr. Jane Smith', '{"specialty": "Endocrinology"}'),
  ('DEV_E1390', 'DEVICE', 'Oxygen Concentrator E1390', '{"brand": "Philips"}'),
  ('COND_COPD', 'CONDITION', 'COPD', '{"icd10": "J44"}'),
  ('COMP_PHILIPS', 'COMPANY', 'Philips Respironics', '{"country": "USA"}');
```

**Relationships table:**
```sql
CREATE TABLE INTELLIGENCE.KG_RELATIONSHIPS (
  relationship_id STRING PRIMARY KEY,
  source_entity_id STRING,
  relationship_type STRING,  -- PRESCRIBES, TREATS, MANUFACTURED_BY
  target_entity_id STRING,
  properties VARIANT  -- Strength, frequency, etc.
);

-- Examples
INSERT INTO INTELLIGENCE.KG_RELATIONSHIPS VALUES
  ('REL_1', 'PROV_123', 'PRESCRIBES', 'DEV_E1390', '{"count": 45}'),
  ('REL_2', 'DEV_E1390', 'TREATS', 'COND_COPD', '{"efficacy": "high"}'),
  ('REL_3', 'DEV_E1390', 'MANUFACTURED_BY', 'COMP_PHILIPS', NULL);
```

**Graph traversal query:**

```sql
-- Find all devices prescribed by endocrinologists for COPD
WITH provider_devices AS (
  SELECT
    e1.entity_name AS provider,
    e2.entity_name AS device
  FROM INTELLIGENCE.KG_RELATIONSHIPS r
  JOIN INTELLIGENCE.KG_ENTITIES e1 ON r.source_entity_id = e1.entity_id
  JOIN INTELLIGENCE.KG_ENTITIES e2 ON r.target_entity_id = e2.entity_id
  WHERE r.relationship_type = 'PRESCRIBES'
    AND e1.properties:specialty = 'Endocrinology'
),
device_conditions AS (
  SELECT
    e2.entity_name AS device,
    e3.entity_name AS condition
  FROM INTELLIGENCE.KG_RELATIONSHIPS r
  JOIN INTELLIGENCE.KG_ENTITIES e2 ON r.source_entity_id = e2.entity_id
  JOIN INTELLIGENCE.KG_ENTITIES e3 ON r.target_entity_id = e3.entity_id
  WHERE r.relationship_type = 'TREATS'
    AND e3.entity_name = 'COPD'
)
SELECT DISTINCT pd.device
FROM provider_devices pd
JOIN device_conditions dc ON pd.device = dc.device;
```

**Use case:** AI can answer complex questions like "What devices do endocrinologists prescribe for COPD?" by traversing the graph.

**[Optional]: Knowledge graphs are powerful but add complexity. Only implement if you have complex relational queries.**

---

## Part 6: Putting It All Together

### The Complete Intelligence Stack

```
┌─────────────────────────────────────────────────────────┐
│                  USER QUESTION                          │
│  "What's the total spend on oxygen concentrators         │
│   by endocrinologists in California?"                    │
└─────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────┐
│              ROUTING LAYER (OPTIONAL)                    │
│  Determines: Cortex Analyst vs Cortex Search vs Hybrid  │
└─────────────────────────────────────────────────────────┘
        │                        │
        ├─ Lookup needed? ───────┤
        │                        │
        ▼                        ▼
┌───────────────────┐    ┌──────────────────────┐
│  CORTEX SEARCH    │    │  CORTEX ANALYST      │
│  (Find oxygen     │    │  (Aggregate spend    │
│   concentrators)  │    │   by specialty +     │
│                   │    │   state)             │
└───────────────────┘    └──────────────────────┘
        │                        │
        │  Returns HCPCS codes   │
        │  ['E1390', 'E1391']    │
        │                        │
        └───────┬────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│             SEMANTIC MODEL                               │
│  - Knows: total_allowed_amount is a measure             │
│  - Knows: provider_specialty is in DIM_PROVIDER         │
│  - Knows: How to join FACT ← DIM_PROVIDER               │
└─────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│             GENERATED SQL                                │
│  SELECT                                                  │
│    p.provider_specialty,                                 │
│    p.provider_state,                                     │
│    SUM(f.total_allowed_amount) AS total_spend           │
│  FROM ANALYTICS.FACT_DMEPOS_CLAIMS f                    │
│  JOIN ANALYTICS.DIM_PROVIDER p                          │
│    ON f.provider_npi = p.provider_npi                   │
│  WHERE f.hcpcs_code IN ('E1390', 'E1391')               │
│    AND p.provider_specialty = 'Endocrinology'           │
│    AND p.provider_state = 'CA'                          │
│  GROUP BY p.provider_specialty, p.provider_state;       │
└─────────────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────┐
│             RESULT                                       │
│  Specialty: Endocrinology                                │
│  State: CA                                               │
│  Total Spend: $1,234,567                                 │
└─────────────────────────────────────────────────────────┘
```

**[VIDEO PLACEHOLDER: 2-minute demo of this complete flow in Snowflake Intelligence]**

---

## Best Practices Summary

### Context Engineering
- ✅ Add comments to every column
- ✅ Build a queryable metadata catalog
- ✅ Track temporal context (valid_from, valid_to)
- ✅ Document relationships (foreign keys + metadata)
- ✅ Encode business rules

### Semantic Models
- ✅ Describe grain clearly
- ✅ Add synonyms for every dimension/measure
- ✅ Provide sample values
- ✅ Create verified queries for regression testing
- ✅ Version control (Git + Snowflake)

### Cortex Search
- ✅ Use hybrid search (keywords + vectors)
- ✅ Materialize search corpuses for performance
- ✅ Concatenate fields for richer search (brand + description)
- ✅ Set appropriate TARGET_LAG (balance freshness vs cost)

### Embeddings & RAG
- ✅ Use embeddings for semantic search
- ✅ Chunk documents into paragraphs (not sentences, not pages)
- ✅ Store embeddings in VECTOR columns
- ✅ Use Cortex Complete for answer generation

### Knowledge Graphs
- ⚠️ Only if you have complex relational queries
- ✅ Start simple (entities + relationships tables)
- ✅ Use graph traversal for multi-hop queries

---

## Common Pitfalls

### Pitfall 1: Vague Column Descriptions

**Bad:**
```sql
amt FLOAT COMMENT 'Amount'
```

**Good:**
```sql
avg_allowed_amount FLOAT COMMENT 'Average Medicare-allowed reimbursement amount per service in USD. Includes both patient responsibility and plan payment. Range: $0.01 to $50,000. Typical: $50-500 for supplies, $1,000-5,000 for equipment.'
```

---

### Pitfall 2: Missing Synonyms

**Bad:** Only define `total_reimbursement`

**Good:** Add synonyms: `total_payment`, `total_cost`, `total_allowed_amount`, `total_spend`

Users ask questions in different ways. AI needs to understand them all.

---

### Pitfall 3: No Verified Queries

**Result:** Semantic model changes, queries break, nobody notices for weeks

**Fix:** Create 10-20 verified queries, run them nightly

---

### Pitfall 4: Pointing Search at Raw Tables

**Problem:** Search corpus rebuilds on every query (slow, expensive)

**Fix:** Materialize search corpus in a view/table, point search service at that

---

## Conclusion: You're Now an Intelligence Expert

You've learned:

✅ **Context Engineering** (self-describing data)
✅ **Semantic Models** (teaching AI your business logic)
✅ **Cortex Search** (finding things beyond keywords)
✅ **Embeddings & RAG** (semantic similarity and document search)
✅ **Knowledge Graphs** (mapping relationships for AI)

**The Intelligence Layer is complete.**

Now your data can explain itself.

---

## What's Next

**Continue the series:**

🏗️ **[Part 2: The Foundation Layer](#)**
Build the data architecture that makes this intelligence possible. Medallion design, schema organization, storage optimization, and automation.

🛡️ **[Part 3: The Trust Layer](#)**
Make your AI system production-ready. Governance, data quality, evaluation frameworks, and continuous improvement.

---

## Resources

**GitHub Repository:**
[Snowflake Intelligence Medicare Demo](https://github.com/YOUR_USERNAME/snowflake-intelligence-medicare-pos-analyst)

**Official Documentation:**
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Cortex Embeddings](https://docs.snowflake.com/en/user-guide/snowflake-cortex/vector-embeddings)

---

## Let's Talk

**Built a semantic model? Share your lessons learned.**

**Struggling with search relevance? Drop a comment.**

**Found this helpful?**
- ⭐ Star the [GitHub repo](#)
- 🔗 Share on LinkedIn
- 💬 Leave a comment

---

**Next up:** [The Trust Layer](#) - Where we make this system reliable, auditable, and continuously improving.

*Now go teach your data to explain itself. Your users will thank you.* 🧠
