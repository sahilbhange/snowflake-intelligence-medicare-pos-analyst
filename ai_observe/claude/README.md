# AI Observability for Semantic Analyst Validation

**Automated quality evaluation, tracing, and A/B testing for Cortex Analyst responses.**

## Quick Start

### 1. Setup Snowflake
```sql
-- Run setup script
source ai_observe/setup.sql
```

### 2. Install Python Dependencies
```bash
pip install trulens-core trulens-connectors-snowflake trulens-providers-cortex --upgrade
```

### 3. Run First Evaluation
```python
from implementation_code import SemanticAnalyst, initialize_session

session, tru_session = initialize_session()
analyst = SemanticAnalyst(session, '@ANALYTICS.CORTEX_SEM_MODEL_STG', 'v1.3.2')

response = analyst.query("What are the top 5 states by claims?")
print(f"Relevance: {response['metrics']['answer_relevance']}")
```

---

## What's Included

| File | Purpose |
|------|---------|
| `ai_observability_integration.md` | Full strategy, architecture, ROI analysis |
| `implementation_code.py` | Python SDK implementation with instrumentation |
| `setup.sql` | Snowflake tables, views, tasks, procedures |
| `README.md` | This file |

---

## Key Capabilities

### 1. Automated Quality Evaluation
- **Answer Relevance**: 0-1 score (does SQL match question?)
- **Groundedness**: 0-1 score (is SQL based on semantic model?)
- **Context Relevance**: 0-1 score (were correct contexts retrieved?)
- **Execution Success**: Binary (does SQL run without errors?)

### 2. Execution Tracing
- Full trace: user question → context retrieval → SQL generation → results
- Debug failed queries with span-level attributes
- Compare traces across model versions

### 3. A/B Testing
- Side-by-side comparison of semantic model versions
- Metrics: quality scores, latency, token cost
- Deploy with confidence

---

## Replacing Manual Eval Framework

| Current (Manual) | New (AI Observability) |
|------------------|------------------------|
| Pattern matching (`expected_pattern STRING`) | LLM judge with 0-1 scores |
| Binary pass/fail | Continuous quality metrics |
| 10 hours/week manual review | 2 hours/week strategic review |
| No trace debugging | Full execution traces |
| No A/B testing | Compare versions before deploy |

---

## Usage Examples

### Nightly Regression
```python
from implementation_code import run_nightly_regression

results = run_nightly_regression(
    session=session,
    tru_session=tru_session,
    semantic_model_stage='@ANALYTICS.CORTEX_SEM_MODEL_STG',
    version='v1.3.2'
)

print(f"Pass rate: {results['passed'] / results['total_tests'] * 100}%")
```

### A/B Test Versions
```python
from implementation_code import compare_semantic_model_versions

comparison = compare_semantic_model_versions(
    session=session,
    tru_session=tru_session,
    semantic_model_stage='@ANALYTICS.CORTEX_SEM_MODEL_STG',
    version_a='v1.3.2',
    version_b='v1.4.0',
    eval_seeds=["Top 5 states", "Average payment by HCPCS"]
)

# Deploy v1.4.0 if better
if comparison['v1.4.0']['avg_relevance'] > comparison['v1.3.2']['avg_relevance']:
    print("✓ Deploy v1.4.0")
```

### Check Quality Drift
```sql
-- Weekly drift detection
SELECT * FROM INTELLIGENCE.WEEKLY_QUALITY_DRIFT;

-- Low-quality questions to fix
SELECT * FROM INTELLIGENCE.LOW_QUALITY_QUESTIONS LIMIT 10;
```

---

## Integration with Existing Trust Layer

### Before (3 separate systems)
1. **Eval seeds** → pattern matching
2. **Query logs** → manual review
3. **Human feedback** → no automation

### After (unified)
```sql
SELECT
    query_id,
    question,
    generated_sql,
    -- AI Observability metrics
    answer_relevance_score,
    groundedness_score,
    -- Human feedback
    feedback_text,
    -- Combined quality
    (answer_relevance_score + groundedness_score + context_relevance_score) / 3 AS quality_score
FROM INTELLIGENCE.UNIFIED_QUERY_ANALYTICS
WHERE created_at > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY quality_score ASC
LIMIT 20;
```

---

## Monitoring & Alerts

### Daily Quality Check (automated)
- Runs every morning at 6 AM
- Alerts if pass rate <95%
- Stored in `INTELLIGENCE.QUALITY_ALERTS`

```sql
SELECT * FROM INTELLIGENCE.QUALITY_ALERTS WHERE status = 'OPEN';
```

### Weekly Drift Alert
- Runs every Monday at 7 AM
- Alerts if quality drifts >10% from baseline
- Identifies regression before users notice

---

## Cost Estimate

| Component | Monthly Cost |
|-----------|--------------|
| Cortex Complete (LLM judging, 200 evals) | ~$150 |
| Warehouse compute | ~$50 |
| Event table storage | ~$10 |
| **Total** | **~$210/month** |

**ROI**: Saves 8 hours/week (~$49,000/year) vs manual validation.

---

## Next Steps

### Immediate (This Week)
- [ ] Run `setup.sql` in Snowflake
- [ ] Install Python dependencies
- [ ] Test single eval seed as POC

### Short-term (Next 2 Weeks)
- [ ] Instrument full semantic analyst pipeline
- [ ] Run parallel validation (manual vs automated)
- [ ] Validate metrics with human feedback

### Medium-term (Month 2)
- [ ] Migrate nightly regression to AI Observability
- [ ] Enable automated alerts
- [ ] Build Snowsight dashboard

### Long-term (Quarter 2)
- [ ] Extend to other Cortex services (Search, Complete)
- [ ] Auto-promote high-quality questions to eval seeds
- [ ] Feedback loop: low scores → auto-ticket for model update

---

## References

- [Snowflake AI Observability Docs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability)
- [Evaluation Guide](https://docs.snowflake.com/en/user-guide/snowflake-cortex/ai-observability/evaluate-ai-applications)
- [Trust Layer Article](../medium/claude/subarticle_3_trust_layer_updated.md)
- [GitHub Repo](https://github.com/sahilbhange/snowflake-intelligence-medicare-pos-analyst)

---

## Questions?

**How does this differ from current eval seeds?**
- Current: Binary pattern matching (SQL contains "ORDER BY")
- New: LLM judging with continuous scores (0.85 relevance, 0.92 groundedness)

**Can I keep existing eval seeds?**
- Yes, run in parallel during validation phase
- Migrate gradually once confident in AI Observability results

**What if LLM judge is wrong?**
- Compare with human feedback in `UNIFIED_QUERY_ANALYTICS`
- Tune judge prompts based on discrepancies
- Use multiple judges for critical evaluations

**Does this work with Cortex Search too?**
- Yes, instrument any Cortex AI service
- Similar pattern: instrument → evaluate → trace → improve
