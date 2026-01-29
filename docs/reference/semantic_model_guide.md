# Building a Semantic Model for Snowflake Cortex Analyst

A learning guide using the DMEPOS Medicare Claims semantic model as a worked example.

---

## What Is a Semantic Model and Why Do We Need One?

Snowflake Cortex Analyst is a natural-language-to-SQL engine. When a user asks _"What are the top 5 HCPCS codes by claims?"_, Cortex Analyst doesn't just guess -- it reads a **semantic model** (a YAML file) that tells it:

- What tables exist and how they join
- What each column means in business terms
- Which columns are dimensions (group-by candidates) vs. facts (aggregation candidates)
- Pre-built metrics with correct SQL expressions
- Synonyms so natural language maps to the right column
- Filters for common business slices
- Verified queries as few-shot examples for the LLM

Without a semantic model, the LLM would have to infer all of this from raw table DDL -- leading to wrong joins, incorrect aggregations, and hallucinated column names. The semantic model is the **contract between your data warehouse and the LLM**.

---

## Anatomy of the YAML

The model file (`models/DMEPOS_SEMANTIC_MODEL.yaml`) has six top-level sections:

```
name / description          # Identity
tables[]                    # Table definitions (dims, facts, metrics, filters)
relationships[]             # Join paths
verified_queries[]          # Few-shot SQL examples
module_custom_instructions  # Guardrails for SQL generation
```

Let's walk through each.

---

## 1. Tables: Dimensions and Facts

We follow a **star schema** pattern with two tables:

| Table | Role | Grain |
|-------|------|-------|
| `DIM_PROVIDER` | Dimension | One row per provider NPI |
| `FACT_CLAIMS` | Fact | One row per provider + HCPCS code |

### Why This Matters

Cortex Analyst needs to know which table is the "center" of analysis (the fact) and which tables provide descriptive attributes (dimensions). This drives:
- **Join direction**: fact -> dimension, never the reverse
- **Aggregation logic**: metrics live on the fact; dimensions are for grouping/filtering

### Dimension Columns

Each dimension column is declared with:

```yaml
- name: PROVIDER_SPECIALTY_DESC
  synonyms:                          # Alternative names users might say
    - medical specialty
    - provider specialty
    - specialty
  description: Specialty description  # Human-readable label
  expr: dim_provider.provider_specialty_desc   # Actual SQL expression
  data_type: VARCHAR(16777216)
  sample_values:                      # Helps the LLM map free text -> real values
    - Family Practice
    - Internal Medicine
    - Nurse Practitioner
```

**Key design decisions in our model:**

- **`expr` uses table-qualified names** (`dim_provider.provider_specialty_desc`) so the generated SQL is unambiguous when joining.
- **`synonyms`** are critical -- they bridge natural language ("specialty") to the actual column. Without them, the LLM may not find the right field.
- **`sample_values`** anchor the LLM to real data values. If a user asks about "family practice", the LLM can match it to the exact string `Family Practice`.
- **Computed dimensions are valid**: `PROVIDER_NAME` uses `concat_ws(' ', ...)` to create a full name from first+last. The model exposes _derived_ columns, not just raw ones.

### Fact Columns

Fact columns represent pre-aggregated measures at the grain of the table:

```yaml
facts:
  - name: TOTAL_SUPPLIER_CLAIMS
    description: Total claims (row-level)
    expr: fact_claims.total_supplier_claims
    data_type: NUMBER(38,0)
    access_modifier: public_access
```

These are the raw building blocks. **They are NOT the final metrics** -- they're the columns that metrics aggregate over.

### Primary Keys

```yaml
primary_key:
  columns:
    - REFERRING_NPI
    - HCPCS_CODE
```

Declared on each table to define grain and enable correct joins. `DIM_PROVIDER` has a single-column key (NPI), `FACT_CLAIMS` has a composite key (NPI + HCPCS code).

---

## 2. Metrics: Pre-Built Aggregations

Metrics are the most important section for Cortex Analyst accuracy. They define **exactly how** to aggregate:

```yaml
metrics:
  - name: TOTAL_CLAIMS_SUM
    synonyms:
      - claim count
      - total claims
    description: Total claims
    expr: sum(fact_claims.total_supplier_claims)
    access_modifier: public_access

  - name: PAYMENT_TO_ALLOWED_RATIO
    description: Payment-to-allowed ratio
    expr: avg(fact_claims.avg_supplier_medicare_payment) / nullif(avg(fact_claims.avg_supplier_medicare_allowed), 0)
```

### Why Pre-Built Metrics Matter

Without metrics, when a user asks "total claims", the LLM must decide: is it `SUM()`? `COUNT()`? `COUNT(DISTINCT)`? With a metric, the answer is explicit.

### Patterns in Our Model

| Pattern | Example | Purpose |
|---------|---------|---------|
| **Simple aggregation** | `sum(total_supplier_claims)` | Volume metrics |
| **Average of averages** | `avg(avg_supplier_medicare_payment)` | Payment metrics (data is pre-averaged at grain) |
| **Ratio with NULLIF** | `sum(x) / nullif(sum(y), 0)` | Derived ratios, safe from divide-by-zero |

The `NULLIF` pattern is essential -- it prevents divide-by-zero errors and returns NULL instead, which is the correct semantic behavior.

---

## 3. Filters: Named Business Slices

```yaml
filters:
  - name: high_volume_providers
    description: Providers with more than 100 total claims
    expr: total_supplier_claims > 100

  - name: top_states
    description: Focus on states with highest claim volume (TX, CA, NY, FL, PA)
    expr: provider_state in ('TX', 'CA', 'NY', 'FL', 'PA')
```

Filters are reusable WHERE clauses the LLM can apply when the user's question matches. They:
- Reduce hallucination (the LLM uses the pre-defined expression instead of guessing)
- Standardize common business definitions ("high volume" always means > 100 claims)
- Are referenced by name in `module_custom_instructions` to tell the LLM when to apply them

---

## 4. Relationships: Join Paths

```yaml
relationships:
  - name: FACT_TO_PROVIDER
    left_table: FACT_CLAIMS
    right_table: DIM_PROVIDER
    relationship_columns:
      - left_column: REFERRING_NPI
        right_column: PROVIDER_NPI
```

This tells Cortex Analyst how to join tables. The relationship is declared once and used anytime a query needs both fact data and provider attributes.

**Design note:** The column names differ (`REFERRING_NPI` vs `PROVIDER_NPI`), which is common in real data warehouses. The semantic model bridges this gap so the LLM doesn't need to guess the join condition.

---

## 5. Verified Queries: Few-Shot Examples

```yaml
verified_queries:
  - name: top_hcpcs_by_claims
    question: What are the top 5 HCPCS codes by total supplier claims?
    sql: |
      select hcpcs_code, sum(total_supplier_claims) as claims
      from fact_claims
      group by hcpcs_code
      order by claims desc
      limit 5
    use_as_onboarding_question: true
    verified_by: Sahil Bhange
```

Verified queries are **the single most impactful accuracy lever**. They serve as:

1. **Few-shot examples** for the LLM -- when a user asks something similar, the model can pattern-match
2. **Regression tests** -- you know the expected SQL for these questions
3. **Onboarding questions** -- `use_as_onboarding_question: true` surfaces them as suggestions in the Snowsight UI

### Coverage Strategy in Our Model

Our 15 verified queries cover:

| Category | Count | Examples |
|----------|-------|---------|
| Aggregation by dimension | 4 | By specialty, by state, by ZIP |
| Top-N ranking | 3 | Top HCPCS by claims, by beneficiaries |
| Filtered subsets | 3 | California providers, rentals only, DME codes |
| Derived metrics | 3 | Payment ratio by state, efficiency by specialty |
| Single-code lookups | 2 | E1390 summary, E0431 summary |

This gives the LLM diverse patterns to learn from: simple aggregations, joins, filters, ratios, and LIMIT queries.

---

## 6. Custom Instructions: Guardrails

```yaml
module_custom_instructions:
  sql_generation: |
    For top or highest questions, include ORDER BY on the metric and LIMIT 5-10.
    Use named filters when relevant.
    Always round monetary amounts to 2 decimals.
  question_categorization: |
    Accept questions about DMEPOS claims, providers, HCPCS codes, Medicare payments, and geography.
    Reject questions requesting patient-level or identifiable data.
    For device definitions or code lookups, suggest Cortex Search sources.
```

These are direct instructions to the LLM that shape SQL generation behavior. Two sections:
- **`sql_generation`**: SQL style rules (ordering, rounding, filter usage)
- **`question_categorization`**: Scope boundaries and routing guidance (what to answer vs. reject vs. redirect)

---

## Design Principles Applied

### 1. Star Schema Alignment
The model mirrors a classic star schema -- one fact table, one dimension table, joined via a foreign key. This is the simplest and most effective pattern for Cortex Analyst.

### 2. Business Language as First Class
Synonyms, descriptions, and sample values are not optional extras -- they're the primary interface between natural language and SQL. Every user-facing column should have at least a description and, for high-cardinality or ambiguous columns, synonyms and sample values.

### 3. Defense Against Hallucination
- **Metrics**: prevent wrong aggregation functions
- **Filters**: prevent wrong WHERE clauses
- **Verified queries**: provide correct patterns to follow
- **Custom instructions**: set explicit boundaries

### 4. Safe SQL Patterns
- `NULLIF` in all division expressions
- Table-qualified column references
- Explicit data types declared

---

## Improvement Opportunities

After reviewing the model, here are areas that could strengthen it:

### High Impact

1. **Missing `join_type` on relationships**
   The relationship declaration doesn't specify `LEFT JOIN` vs `INNER JOIN`. Snowflake's semantic model spec supports a `join_type` field. Without it, the LLM may default to INNER JOIN, which drops fact rows without matching providers. Given the verified queries use both `LEFT JOIN` and `JOIN` inconsistently, explicitly declaring this would improve consistency.

2. **Descriptions are too terse**
   Many descriptions just echo the column name ("Provider city", "HCPCS code"). Richer descriptions help the LLM understand context:
   ```yaml
   # Current
   description: Provider city

   # Better
   description: City where the referring provider's practice is located
   ```

3. **Missing synonyms on several dimensions**
   `PROVIDER_CITY`, `PROVIDER_COUNTRY`, `PROVIDER_FIRST_NAME`, `PROVIDER_LAST_NAME`, `PROVIDER_ZIP`, `RBCS_ID`, `HCPCS_DESCRIPTION` have no synonyms. Adding them (e.g., `zip code`, `postal code` for PROVIDER_ZIP; `category` for RBCS_ID) would improve natural language matching.

4. **No `time_dimensions` section**
   The model has no time/date dimension. This means temporal questions ("claims last year", "trend over time") will fail. If the underlying data has a year or period column, exposing it would unlock time-series analysis. If it genuinely doesn't exist (single snapshot), a note in `question_categorization` should explicitly say "this data is a single time period snapshot, time-based questions are not supported."

5. **Duplicate NPI synonyms across tables**
   Both `DIM_PROVIDER.PROVIDER_NPI` and `FACT_CLAIMS.REFERRING_NPI` share the synonym `npi` and `supplier_npi`. This creates ambiguity -- when a user says "NPI", the LLM doesn't know which table's column to use. Remove the synonyms from the fact table's `REFERRING_NPI` since users will conceptually think of NPI as a provider attribute.

### Medium Impact

6. **Metric descriptions lack units and context**
   Metric descriptions like "Total claims" don't specify that this is a SUM, or what the unit is. Better:
   ```yaml
   description: >
     Sum of all supplier claims across selected provider-HCPCS combinations.
     Unit: count. Use for volume analysis and ranking.
   ```

7. **`RBCS_ID` has no description or sample values**
   Users may not know what RBCS (Restructured BETOS Classification System) is. Adding a description and sample values would help the LLM map questions about "equipment categories" or "code categories" to this field.

8. **Filters reference columns from across tables**
   Filters like `california_providers` use `provider_state = 'CA'` but are defined on `FACT_CLAIMS`. Since `provider_state` lives in `DIM_PROVIDER`, this implicitly requires a join. If the LLM applies the filter without joining, it will fail. Consider either:
   - Moving geographic filters to `DIM_PROVIDER`
   - Using fully qualified expressions: `dim_provider.provider_state = 'CA'`

9. **No `default_aggregation` on fact columns**
   Snowflake semantic models support `default_aggregation` (e.g., `sum`, `avg`) on fact columns. Adding these would give the LLM a hint when a user doesn't specify an aggregation function.

10. **Verified queries could use the semantic model's own names**
    The SQL in verified queries references raw column names (`total_supplier_claims`) rather than metric names (`TOTAL_CLAIMS_SUM`). While Cortex Analyst generates raw SQL, aligning the verified query style with the metrics helps the LLM learn to use the defined aggregation patterns.

### Low Impact / Nice to Have

11. **`AVG_MEDICARE_STANDARD` has no synonyms or explanation**
    What does "standard" mean in this context? (It's the standardized allowed amount removing geographic adjustments.) This is domain-specific and should be explained.

12. **Consider adding a `CHARGE_TO_ALLOWED_RATIO` metric**
    The model has `PAYMENT_TO_ALLOWED_RATIO` but not `CHARGE_TO_ALLOWED_RATIO` (submitted charge vs allowed). This is a common billing analysis metric.

13. **Onboarding question distribution**
    Only 4 of 15 verified queries are marked as onboarding questions. Consider promoting `rentals_vs_nonrentals` and `top_hcpcs_by_beneficiaries` since they demonstrate different analytical angles.

14. **Version mismatch**
    The YAML header says `v1.1.0` but the lifecycle doc says current version is `1.0.0`. Should be reconciled.

---

## How to Build Your Own Semantic Model (Checklist)

1. **Start with your data model** -- identify the fact and dimension tables, their grain, and join keys
2. **Declare every column** you want queryable as a dimension or fact, with descriptions
3. **Add synonyms** for any column a business user might refer to by a different name
4. **Add sample values** for categorical columns (states, specialties, codes) -- this is how the LLM maps free text to real values
5. **Define metrics** for every aggregation pattern your users will need -- don't leave aggregation choice to the LLM
6. **Use NULLIF** in all division-based metrics
7. **Create named filters** for common business slices
8. **Write 10-20 verified queries** covering diverse patterns (aggregation, ranking, filtering, joins, ratios)
9. **Add custom instructions** to set SQL style rules and scope boundaries
10. **Iterate** -- review query logs, collect feedback, add more verified queries for patterns the LLM gets wrong

---

## References

- [Snowflake Cortex Analyst Semantic Model Spec](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst/semantic-model-spec)
- [Metric Catalog](metric_catalog.md) -- business definitions for all metrics
- [Semantic Model Lifecycle](../governance/semantic_model_lifecycle.md) -- versioning and governance
- [Semantic Model YAML](../../models/DMEPOS_SEMANTIC_MODEL.yaml) -- the actual model file
