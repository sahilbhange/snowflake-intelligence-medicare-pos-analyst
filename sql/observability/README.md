# AI Observability Governance

**Problem:** AI Observability events = 130 rows/question + nested JSON
**Solution:** View → Stored Proc → One row/question

**Location:** `sql/observability/`

---

## Files (Execution Sequence)

| # | File | Purpose | Required Role |
|---|------|---------|---------------|
| 1 | `01_grant_all_privileges.sql` | Grant all required privileges | ACCOUNTADMIN |
| 2 | `02_create_governance_objects.sql` | Create table, view, stored proc | MEDICARE_POS_INTELLIGENCE |
| 3 | `03_create_scheduled_task.sql` | **Optional** - Daily auto-population | MEDICARE_POS_INTELLIGENCE |
| 4 | `04_create_quality_tables.sql` | Quality evaluation tables for TruLens | MEDICARE_POS_INTELLIGENCE |
| - | `README.md` | This file | - |

---

## Setup (Sequential Execution)

### Step 1: Grant All Privileges

```bash
snow sql -c sf_int -f 01_grant_all_privileges.sql
```

Grants:
- Schema/database usage
- Object creation (TABLE, VIEW, PROCEDURE, TASK)
- Warehouse usage
- AI Observability application role

### Step 2: Create Governance Objects

```bash
snow sql -c sf_int -f 02_create_governance_objects.sql
```

Creates:
- Table: `AI_AGENT_GOVERNANCE`
- View: `V_AI_GOVERNANCE_PARAMS`
- Stored Proc: `POPULATE_AI_GOVERNANCE()`

### Step 3: Create Scheduled Task (Optional)

```bash
snow sql -c sf_int -f 03_create_scheduled_task.sql
```

Creates daily task to auto-populate governance data.

### Step 4: Create Quality Evaluation Tables (Optional)

```bash
snow sql -c sf_int -f 04_create_quality_tables.sql
```

Creates tables for TruLens quality evaluation integration (see [ai_observe/README.md](../../ai_observe/README.md)).

---

## How It Works

**Architecture:**

```
AI_OBSERVABILITY_EVENTS (130 rows/question)
           ↓
V_AI_GOVERNANCE_PARAMS (view: 1 row/question)
           ↓
POPULATE_AI_GOVERNANCE (stored proc: just inserts from view)
           ↓
AI_AGENT_GOVERNANCE (table: clean governance data)
```

**Benefits:**
- **View** = reusable, no stored proc complexity
- **Stored proc** = 10 lines (was 200+), just INSERT FROM view
- **Table** = fast queries, no re-parsing JSON

---

## Flattening Strategy

**Challenge:** Each trace_id has **8 rows** in AI_OBSERVABILITY_EVENTS (different span types)

**Solution:** View consolidates 8 rows → 1 row by:
1. **root_span CTE** → Extracts from `record_root` span (question, response, status)
2. **planning_span CTE** → Extracts from `ResponseGeneration` span (model, tokens, SQL)
3. **tool_span CTE** → Extracts from `Tool` spans (tools used, tool types)
4. **LEFT JOIN** → Combines all three on trace_id

**Result:** One governance record per user question with all parameters from multiple spans

---

## Usage

### Populate Data

```sql
-- Last 7 days
CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(7);

-- Last 30 days
CALL GOVERNANCE.POPULATE_AI_GOVERNANCE(30);
```

### Query Results

```sql
-- All governance data
SELECT * FROM GOVERNANCE.AI_AGENT_GOVERNANCE
ORDER BY completion_timestamp DESC;

-- Use the view directly (no stored proc needed)
SELECT * FROM GOVERNANCE.V_AI_GOVERNANCE_PARAMS
WHERE query_date = CURRENT_DATE();
```

---

## Key Queries

### Cost by User

```sql
SELECT
    user_name,
    COUNT(*) AS requests,
    SUM(total_tokens) AS tokens,
    SUM(estimated_cost_usd) AS cost
FROM GOVERNANCE.AI_AGENT_GOVERNANCE
GROUP BY user_name;
```

### Slow Queries

```sql
SELECT user_question, total_duration_ms, generated_sql
FROM GOVERNANCE.AI_AGENT_GOVERNANCE
WHERE performance_category IN ('slow', 'needs_optimization');
```

### Daily Metrics

```sql
SELECT
    query_date,
    COUNT(*) AS total,
    SUM(CASE WHEN is_successful THEN 1 ELSE 0 END) AS successful,
    AVG(total_duration_ms) AS avg_duration,
    SUM(estimated_cost_usd) AS total_cost
FROM GOVERNANCE.AI_AGENT_GOVERNANCE
GROUP BY query_date
ORDER BY query_date DESC;
```

---

## Troubleshooting

### Error: "Object does not exist or not authorized"

**Fix:**
```bash
# Re-run grants as ACCOUNTADMIN
snow sql -c sf_int -f 01_grant_all_privileges.sql
```

**Root cause:** Missing AI Observability application role grant

### Error: "Insufficient privileges on schema"

**Fix:**
```bash
# Re-run grants as ACCOUNTADMIN
snow sql -c sf_int -f 01_grant_all_privileges.sql
```

**Root cause:** Missing schema or object creation privileges

### Check if view works

```sql
SELECT COUNT(*) FROM GOVERNANCE.V_AI_GOVERNANCE_PARAMS;
-- Should return count of questions (not 0)
```

---

## Parameters Extracted

| Category | Columns |
|----------|---------|
| **Identity** | request_id, trace_id, user_name, role_name |
| **Agent** | agent_name, agent_version, planning_model |
| **Query** | user_question, agent_response, question_category |
| **Performance** | total_duration_ms, planning_duration_ms, performance_category |
| **Tokens** | input_tokens, output_tokens, total_tokens, cache_hit_rate_pct |
| **Cost** | estimated_cost_usd ($0.75/1M tokens) |
| **Quality** | execution_status, is_successful, used_verified_query |
| **Generated** | generated_sql |


---

## Source Data: AI_OBSERVABILITY_EVENTS

### Structure

Each user question generates **8+ rows** in `SNOWFLAKE.LOCAL.AI_OBSERVABILITY_EVENTS`:

| Row | RECORD:name | Contains |
|-----|-------------|----------|
| 1 | `AgentV2RequestResponseInfo` | user_question, agent_response, status |
| 2 | `Agent` | Basic span info |
| 3-4 | `ReasoningAgentStepResponseGeneration` | **planning_model, tokens, SQL** |
| 5-8 | Tool executions, context retrieval | Additional metadata |

### Key Insight

**Different span types contain different data** - must join to get complete picture:

```sql
-- Root span has question/answer
RECORD_ATTRIBUTES:"ai.observability.record_root.input" = "Top 5 states by claims"

-- Planning span has tokens/cost  
RECORD_ATTRIBUTES:"snow.ai.observability.agent.planning.token_count.total" = 30005
```

---

## How the View Extracts Data

### Three CTEs Join on trace_id

```sql
WITH
root_span AS (
    -- Filter: span_type = 'record_root'
    -- Extract: user_question, agent_response, status, duration
),
planning_span AS (
    -- Filter: RECORD:name LIKE '%ResponseGeneration%'
    -- Extract: planning_model, tokens, SQL (from JSON array)
),
tool_span AS (
    -- Filter: RECORD:name LIKE '%Tool%'
    -- Extract: tools_used, tool_types (ARRAY_AGG)
)
SELECT * FROM root_span
LEFT JOIN planning_span ON trace_id
LEFT JOIN tool_span ON trace_id
-- Result: 1 complete row per question
```

### Why This Approach?

**Before fix:** Only queried `record_root` → Many NULL columns
**After fix:** Joins `root_span` + `planning_span` + `tool_span` → All columns populated

---

## Complete Workflow

```
1. Snowflake Intelligence generates events
           ↓
2. AI_OBSERVABILITY_EVENTS stores spans (8+ rows/question)
           ↓
3. V_AI_GOVERNANCE_PARAMS view joins spans (1 row/question)
           ↓
4. POPULATE_AI_GOVERNANCE proc inserts into table
           ↓
5. Query GOVERNANCE.AI_AGENT_GOVERNANCE for analytics
```

