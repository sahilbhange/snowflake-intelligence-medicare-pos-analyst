# AI Observability Integration for Semantic Analyst Validation

## Executive Summary

Snowflake AI Observability can **replace and enhance** the current manual validation framework with automated LLM-based evaluation, execution tracing, and continuous quality monitoring.

**Current Gap**: Manual pattern matching (`expected_pattern` in eval seeds) + human feedback.

**AI Observability Solution**: Automated LLM judging + trace-based debugging + metrics dashboard.

---

## 1. Current State Analysis

### What You Already Have (Trust Layer Article)

| Component | Current Implementation | Limitation |
|-----------|----------------------|------------|
| Eval Seeds | Pattern matching (`expected_pattern STRING`) | Binary pass/fail, misses semantic correctness |
| Test Results | `pattern_matched BOOLEAN` | Doesn't measure quality, only syntax |
| Human Feedback | Manual thumbs up/down | Reactive, not automated |
| Query Logs | Records question + SQL | No execution trace or context |

**Example limitation:**
```sql
-- Current eval seed
expected_pattern: 'ORDER BY total_supplier_claims DESC LIMIT 5'

-- Problem: SQL could match pattern but return wrong data
-- (wrong joins, wrong filters, wrong aggregation)
```

---

## 2. How AI Observability Solves This

### Core Capabilities

**1. Evaluations (LLM-as-Judge)**
- Automated quality scoring using `llama3.1-70b` or other Cortex models
- Metrics: coherence, answer relevance, groundedness, context relevance, correctness

**2. Tracing**
- Captures full execution path: user question → semantic model retrieval → SQL generation → results
- Attribute mapping for debugging (query text, retrieved contexts, generated SQL)

**3. Comparison**
- A/B test different semantic model versions
- Compare prompt templates
- Identify optimal configurations before deployment

---

## 3. Integration Architecture

### Proposed Stack

```
User Question
      │
      ▼
┌─────────────────────────────────┐
│ Cortex Analyst (Semantic Model) │
│  - EXTERNAL AGENT object         │
│  - Instrumented with @instrument │
└─────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────┐
│ AI Observability Tracing         │
│  - Input: user question          │
│  - Context: semantic model YAML  │
│  - Output: generated SQL         │
│  - Execution: query results      │
└─────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────┐
│ Automated Evaluation             │
│  - Answer Relevance (0-1)        │
│  - Groundedness (0-1)            │
│  - Context Relevance (0-1)       │
│  - SQL Correctness (vs expected) │
└─────────────────────────────────┘
      │
      ▼
┌─────────────────────────────────┐
│ Event Table Storage              │
│  - INTELLIGENCE.AI_OBSERVABILITY │
│  - Query with existing logs      │
└─────────────────────────────────┘
```

---

## 4. Implementation Plan

### Phase 1: Setup (Week 1)

**Step 1: Install Python SDK**
```bash
pip install trulens-core trulens-connectors-snowflake trulens-providers-cortex --upgrade
```

**Step 2: Grant Privileges**
```sql
-- Grant AI Observability roles
GRANT APPLICATION ROLE AI_OBSERVABILITY_EVENTS_LOOKUP TO ROLE ANALYST_ROLE;
GRANT CORTEX_USER ON DATABASE SNOWFLAKE TO ROLE ANALYST_ROLE;

-- Schema privileges
GRANT CREATE EXTERNAL AGENT ON SCHEMA INTELLIGENCE TO ROLE ANALYST_ROLE;
GRANT CREATE TASK ON SCHEMA INTELLIGENCE TO ROLE ANALYST_ROLE;
```

**Step 3: Create Event Table**
```sql
CREATE EVENT TABLE IF NOT EXISTS INTELLIGENCE.AI_OBSERVABILITY_EVENTS;
```

---

### Phase 2: Instrument Semantic Analyst (Week 2)

**Step 1: Wrap Cortex Analyst Call**

```python
from trulens.core import TruSession, instrument
from trulens.apps.basic import TruApp
from snowflake.snowpark import Session

# Initialize session
session = Session.builder.configs(connection_params).create()
tru_session = TruSession()

# Instrument the semantic analyst function
@instrument(span_type='GENERATION')
def semantic_analyst_query(question: str, semantic_model: str):
    """
    Query Cortex Analyst with observability.

    Args:
        question: User's natural language question
        semantic_model: Semantic model stage path

    Returns:
        dict: SQL and results
    """
    result = session.sql(f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'cortex-analyst',
            OBJECT_CONSTRUCT(
                'messages', ARRAY_CONSTRUCT(
                    OBJECT_CONSTRUCT('role', 'user', 'content', '{question}')
                ),
                'semantic_model_file', '{semantic_model}'
            )
        ) AS response
    """).collect()

    return {
        'sql': result[0]['response']['sql'],
        'results': result[0]['response']['results']
    }

# Register as TruApp
analyst_app = TruApp(
    semantic_analyst_query,
    app_name='DMEPOS_SEMANTIC_ANALYST',
    app_version='v1.3.2'
)
```

**Step 2: Add Retrieval Tracing**

```python
@instrument(span_type='RETRIEVAL')
def get_semantic_context(question: str):
    """
    Retrieve semantic model definitions relevant to question.
    Maps to RETRIEVAL.QUERY_TEXT and RETRIEVAL.RETRIEVED_CONTEXTS.
    """
    # Extract relevant measures/dimensions from semantic model
    # This helps evaluate if correct context was used
    contexts = session.sql(f"""
        SELECT measure_name, description
        FROM INTELLIGENCE.SEMANTIC_MODEL_METADATA
        WHERE description ILIKE '%{question}%'
        LIMIT 5
    """).collect()

    return [c['DESCRIPTION'] for c in contexts]
```

---

### Phase 3: Define Evaluation Metrics (Week 2)

**Metric 1: Answer Relevance**
```python
from trulens.providers.cortex import Cortex

cortex_provider = Cortex(session, model_engine='llama3.1-70b')

answer_relevance = cortex_provider.relevance_with_cot_reasons(
    prompt="User asked: {question}",
    response="{generated_sql}"
)
```

**Metric 2: Groundedness (SQL Correctness)**
```python
groundedness = cortex_provider.groundedness_measure_with_cot_reasons(
    source="{semantic_model_yaml}",
    statement="{generated_sql}"
)
```

**Metric 3: Context Relevance (Semantic Model Coverage)**
```python
context_relevance = cortex_provider.qs_relevance_with_cot_reasons(
    question="{user_question}",
    context="{retrieved_semantic_definitions}"
)
```

**Metric 4: SQL Execution Success**
```python
@instrument()
def evaluate_sql_execution(sql: str):
    """Binary: Does SQL execute without errors?"""
    try:
        session.sql(sql).collect()
        return {'success': True, 'error': None}
    except Exception as e:
        return {'success': False, 'error': str(e)}
```

---

### Phase 4: Automated Regression Testing (Week 3)

**Replace current SEMANTIC_TEST_RESULTS with AI Observability**

```python
from trulens.core import Select

# Define evaluation configuration
eval_config = {
    'app': analyst_app,
    'feedback_functions': [
        answer_relevance,
        groundedness,
        context_relevance
    ]
}

# Run nightly regression on eval seeds
eval_seeds = session.table('INTELLIGENCE.ANALYST_EVAL_SET').collect()

for seed in eval_seeds:
    with analyst_app as recording:
        result = semantic_analyst_query(
            question=seed['QUESTION'],
            semantic_model='@ANALYTICS.CORTEX_SEM_MODEL_STG/v1.3.2.yaml'
        )

    # Metrics calculated asynchronously
    # Results stored in AI_OBSERVABILITY_EVENTS table
```

**Query Results Dashboard**

```sql
-- Daily quality metrics
SELECT
    app_name,
    app_version,
    DATE(event_timestamp) AS test_date,
    AVG(answer_relevance_score) AS avg_relevance,
    AVG(groundedness_score) AS avg_groundedness,
    AVG(context_relevance_score) AS avg_context,
    COUNT(*) AS total_tests,
    SUM(CASE WHEN answer_relevance_score < 0.7 THEN 1 ELSE 0 END) AS low_quality_count
FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
WHERE event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
GROUP BY app_name, app_version, DATE(event_timestamp)
ORDER BY test_date DESC;
```

---

### Phase 5: A/B Testing Semantic Model Versions (Week 4)

**Compare v1.3.2 vs v1.4.0**

```python
# Test both versions on same eval seeds
versions = ['v1.3.2', 'v1.4.0']
results = {}

for version in versions:
    app = TruApp(
        semantic_analyst_query,
        app_name='DMEPOS_SEMANTIC_ANALYST',
        app_version=version
    )

    # Run eval seeds
    for seed in eval_seeds:
        with app as recording:
            result = semantic_analyst_query(
                question=seed['QUESTION'],
                semantic_model=f'@ANALYTICS.CORTEX_SEM_MODEL_STG/{version}.yaml'
            )

# Compare in Snowsight UI or SQL
SELECT
    app_version,
    AVG(answer_relevance_score) AS avg_relevance,
    AVG(groundedness_score) AS avg_groundedness,
    AVG(latency_ms) AS avg_latency
FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
WHERE app_name = 'DMEPOS_SEMANTIC_ANALYST'
  AND app_version IN ('v1.3.2', 'v1.4.0')
GROUP BY app_version;
```

**Decision criteria:**
- Deploy v1.4.0 if: avg_relevance > v1.3.2 AND avg_groundedness >= v1.3.2
- Rollback if: avg_relevance drops >5%

---

## 5. Enhanced Trust Layer Schema

### New Table: AI Observability Results

```sql
CREATE OR REPLACE VIEW INTELLIGENCE.SEMANTIC_ANALYST_QUALITY AS
SELECT
    event_id,
    app_name,
    app_version,
    input_prompt AS user_question,
    output_response AS generated_sql,
    -- Quality metrics
    answer_relevance_score,
    groundedness_score,
    context_relevance_score,
    -- Performance
    latency_ms,
    token_count,
    -- Debugging
    trace_id,
    span_attributes,
    event_timestamp
FROM INTELLIGENCE.AI_OBSERVABILITY_EVENTS
WHERE app_name = 'DMEPOS_SEMANTIC_ANALYST';
```

### Integration with Existing Tables

```sql
-- Link AI Observability with existing query logs
CREATE OR REPLACE VIEW INTELLIGENCE.UNIFIED_QUERY_ANALYTICS AS
SELECT
    l.query_id,
    l.user_id,
    l.question,
    l.generated_sql,
    l.success_flag,
    l.semantic_model_version,
    l.created_at,
    -- AI Observability metrics
    o.answer_relevance_score,
    o.groundedness_score,
    o.context_relevance_score,
    o.latency_ms,
    -- Human feedback
    f.feedback_type,
    f.feedback_text
FROM INTELLIGENCE.ANALYST_QUERY_LOG l
LEFT JOIN INTELLIGENCE.SEMANTIC_ANALYST_QUALITY o
    ON l.query_id = o.trace_id
LEFT JOIN INTELLIGENCE.SEMANTIC_FEEDBACK f
    ON l.query_id = f.query_log_id;
```

---

## 6. Monitoring & Alerting

### Weekly Quality Report

```sql
-- Replace manual weekly review with automated alerts
WITH weekly_metrics AS (
    SELECT
        app_version,
        AVG(answer_relevance_score) AS avg_relevance,
        AVG(groundedness_score) AS avg_groundedness,
        STDDEV(answer_relevance_score) AS relevance_stddev,
        COUNT(*) AS query_count
    FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
    WHERE event_timestamp > DATEADD(day, -7, CURRENT_TIMESTAMP())
    GROUP BY app_version
),
baseline_metrics AS (
    SELECT
        app_version,
        AVG(answer_relevance_score) AS baseline_relevance
    FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY
    WHERE event_timestamp BETWEEN DATEADD(day, -30, CURRENT_TIMESTAMP())
                              AND DATEADD(day, -8, CURRENT_TIMESTAMP())
    GROUP BY app_version
)
SELECT
    w.app_version,
    w.avg_relevance AS current_relevance,
    b.baseline_relevance,
    ROUND((w.avg_relevance - b.baseline_relevance) / b.baseline_relevance * 100, 1) AS pct_change,
    CASE
        WHEN w.avg_relevance < 0.7 THEN 'CRITICAL: Quality below threshold'
        WHEN ABS((w.avg_relevance - b.baseline_relevance) / b.baseline_relevance) > 0.1
            THEN 'WARNING: 10%+ drift from baseline'
        ELSE 'OK'
    END AS alert_status
FROM weekly_metrics w
JOIN baseline_metrics b ON w.app_version = b.app_version;
```

### Snowflake Task for Auto-Alerts

```sql
CREATE OR REPLACE TASK INTELLIGENCE.QUALITY_ALERT_TASK
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 6 * * MON America/Los_Angeles'  -- Every Monday 6 AM
AS
    -- Send alert if quality drops
    CALL SYSTEM$SEND_EMAIL(
        'data-engineering@company.com',
        'Semantic Analyst Quality Alert',
        (SELECT alert_status FROM weekly_metrics WHERE alert_status != 'OK')
    );
```

---

## 7. Cost-Benefit Analysis

### Current Manual Approach

| Task | Time/Week | Annual Cost |
|------|-----------|-------------|
| Manual eval seed review | 2 hours | $10,400 (@ $100/hr) |
| Human feedback triage | 3 hours | $15,600 |
| Debug failed queries | 5 hours | $26,000 |
| **Total** | **10 hours** | **$52,000** |

### AI Observability Approach

| Cost Component | Monthly Cost |
|----------------|--------------|
| Cortex Complete (LLM judging) | ~$150 (200 evals × $0.75) |
| Warehouse compute | ~$50 |
| Storage (event table) | ~$10 |
| **Total** | **~$210/month = $2,520/year** |

**Time savings**: 8 hours/week (only 2 hours for strategic review instead of 10 for manual triage)

**ROI**: $52,000 - $2,520 = **$49,480 annual savings** + faster incident detection

---

## 8. Migration Path

### Week 1: Parallel Run
- Keep existing eval seeds
- Add AI Observability instrumentation
- Run both systems side-by-side

### Week 2-3: Validation
- Compare manual pattern matching vs LLM judging
- Identify discrepancies
- Tune evaluation prompts

### Week 4: Cutover
- Deprecate `SEMANTIC_TEST_RESULTS.pattern_matched`
- Switch nightly regression to AI Observability
- Archive old manual results

### Week 5+: Optimize
- Fine-tune LLM judge prompts
- Add custom metrics (e.g., SQL complexity score)
- Build Streamlit dashboard for exec visibility

---

## 9. Key Metrics to Track

### Quality Metrics (from AI Observability)
- **Answer Relevance**: >0.80 target
- **Groundedness**: >0.85 target
- **Context Relevance**: >0.75 target

### Performance Metrics
- **Latency**: <3s P95
- **Success Rate**: >95%
- **Token Cost**: <$500/month

### Business Metrics
- **User Satisfaction**: Correlate AI scores with human feedback
- **Question Coverage**: % of questions answered without escalation
- **Incident MTTR**: Time from quality drop to fix

---

## 10. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| LLM judge hallucinations | False positives/negatives | Use multiple judges, compare with human feedback |
| Cost overrun | Budget exceeded | Set monthly limits, sample eval runs |
| Integration complexity | Delayed rollout | Pilot with 10 eval seeds first |
| Dependency on Cortex availability | Service outage | Fallback to manual pattern matching |

---

## 11. Next Steps

### Immediate (This Week)
1. ✅ Research AI Observability docs
2. ⬜ Set up dev environment with TruLens SDK
3. ⬜ Instrument single eval seed as POC

### Short-term (Next 2 Weeks)
4. ⬜ Instrument full semantic analyst pipeline
5. ⬜ Define custom evaluation metrics
6. ⬜ Run parallel validation (manual vs automated)

### Medium-term (Month 2)
7. ⬜ Migrate nightly regression to AI Observability
8. ⬜ Build Snowsight dashboard for exec reporting
9. ⬜ Implement automated alerts

### Long-term (Quarter 2)
10. ⬜ Extend to other Cortex AI services (Search, Complete)
11. ⬜ Build feedback loop: low scores → auto-ticket for semantic model update
12. ⬜ Publish internal "AI Quality Standards" based on learnings

---

## 12. Conclusion

**AI Observability transforms the Trust Layer from reactive → proactive:**

| Before | After |
|--------|-------|
| Manual pattern matching | Automated LLM judging |
| Binary pass/fail | Continuous quality scores (0-1) |
| CEO finds bugs first | You find bugs first |
| 10 hours/week manual triage | 2 hours/week strategic review |
| No A/B testing | Compare versions before deploy |

**Bottom line**: AI Observability is the missing piece that makes the Trust Layer truly autonomous and scalable.

---

**References**:
- [Snowflake AI Observability Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)
- [TruLens Evaluation Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications)
- [Current Trust Layer Implementation](https://github.com/sahilbhange/snowflake-intelligence-medicare-pos-analyst/blob/main/medium/claude/subarticle_3_trust_layer.md)
