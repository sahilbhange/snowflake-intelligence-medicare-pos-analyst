# Trust Layer Integration: What to Keep vs Overkill

**Created:** 2026-02-08
**Purpose:** Recommendations for integrating AI Observability with existing Trust Layer (article)

---

## TL;DR

**Keep it practical:** Use pattern matching for daily regression. Use LLM evaluation for A/B testing only.

**Cost:** $15/month (not $210/month)

---

## Current State: Two Systems

### Article Trust Layer (Lightweight)
```sql
ANALYST_QUERY_LOG              -- Basic audit: who, what, when
ANALYST_EVAL_SET               -- 20 golden questions (pattern matching)
SEMANTIC_FEEDBACK              -- Human thumbs up/down
SEMANTIC_MODEL_VERSIONS        -- Git versioning + rollback
```

### AI Observability (Deep Tracing)
```sql
AI_AGENT_GOVERNANCE            -- Performance: duration, tokens, cost, trace_id
TruLens Quality Tables         -- LLM scoring: relevance, groundedness
```

**Problem:** Do we need both? What's overkill?

---

## Recommended Architecture

### ✅ Keep Both Systems (Different Purposes)

**ANALYST_QUERY_LOG** → Compliance audit
- Lightweight, always-on
- 7-column table: query_id, user_id, question, generated_sql, success_flag
- Cost: Free (just storage)
- Use for: "Who accessed patient data in last 30 days?"

**AI_AGENT_GOVERNANCE** → Performance analysis
- Heavy, detailed tracing
- 37-column table: trace_id, duration, tokens, cost, cache_hit_rate, tools_used
- Cost: ~$10/month (storage)
- Use for: "Why is this query slow?" "Which user costs most?"

**Link them:** Add `trace_id` column to ANALYST_QUERY_LOG for deep-dive linking.

---

## Evaluation Strategy: Hybrid Approach

### Pattern Matching (Nightly)
```sql
-- ANALYST_EVAL_SET: 20 golden questions
-- Run every night at 2 AM
-- Expected: 'ORDER BY total_claims DESC LIMIT 5'
-- Cost: $0
-- Speed: Fast (20 queries in 2 minutes)
```

**Use for:**
- Daily regression detection
- Quick smoke tests
- Catching SQL syntax breaks

### LLM Evaluation (Selective)
```python
# TruLens: answer_relevance, groundedness, context_relevance
# Run: Pre-deployment A/B testing only
# Cost: ~$5 per A/B test (20 questions × 2 versions)
# Speed: Slow (20 questions in 5 minutes)
```

**Use for:**
- A/B testing v1.3.2 vs v1.4.0 before deployment
- Validating top 10 critical questions
- Quarterly deep quality audit

**Don't use for:**
- Nightly regression (too expensive, too slow)
- Every single user query (overkill)

---

## Cost Comparison

| Approach | Frequency | Monthly Cost |
|----------|-----------|--------------|
| **Pattern matching** | Nightly (20 questions) | $0 |
| **AI_AGENT_GOVERNANCE logging** | Always-on | ~$10 |
| **LLM eval (A/B testing)** | Pre-deployment (2×/month) | ~$5 |
| **LLM eval (nightly)** | Every night | ~$150 |

**Recommendation:** $15/month → Pattern matching daily + LLM eval for A/B only

---

## Implementation Phases

### Phase 1: Article Trust Layer (Week 1)
```
✓ ANALYST_QUERY_LOG
✓ ANALYST_EVAL_SET (20 golden questions)
✓ SEMANTIC_MODEL_VERSIONS
✓ Nightly regression (pattern matching)
✓ Human feedback collection
```

**Result:** Production-ready trust layer. CEO can sleep at night.

---

### Phase 2: Add AI Observability Logging (Week 2)
```
✓ AI_AGENT_GOVERNANCE table
✓ Performance dashboard (Snowsight)
  - Slow queries (>2 seconds)
  - Cost by user
  - Token usage trends
```

**Result:** Performance visibility. Optimize costs.

---

### Phase 3: Selective LLM Evaluation (Week 3)
```
✓ TruLens quality tables (04_create_quality_tables.sql)
✓ A/B testing framework
  - Test v1.3.2 vs v1.4.0 before deployment
  - 10 critical questions only
  - Compare LLM scores vs pattern matching
```

**Result:** Confident deployments. Catch regressions pattern matching misses.

---

### Phase 4: Optimize (Month 2)
```
Review results:
  - Does LLM evaluation find bugs pattern matching missed? → Expand to 20 questions
  - Does LLM evaluation match human feedback? → Trust it more
  - Does LLM evaluation cost too much? → Keep A/B testing only
```

---

## What NOT to Do (Avoid Overkill)

### ❌ Don't Duplicate Query Logging
```
Bad: ANALYST_QUERY_LOG + AI_AGENT_GOVERNANCE both logging same queries
Good: ANALYST_QUERY_LOG for audit, AI_AGENT_GOVERNANCE for analytics
Link: Add trace_id to ANALYST_QUERY_LOG for deep-dive when needed
```

### ❌ Don't Run LLM Eval on Everything
```
Bad: Every user query gets LLM evaluation (expensive, slow)
Good: Pattern matching daily, LLM eval for A/B testing
```

### ❌ Don't Over-Engineer Day 1
```
Bad: Build all 5 components before first deployment
Good: Start with ANALYST_QUERY_LOG + EVAL_SET, iterate
```

### ❌ Don't Skip Pattern Matching
```
Bad: "LLM evaluation is better, remove pattern matching"
Good: Pattern matching is free and fast, keep it for daily regression
```

---

## Unified Query Analytics View

**Optional:** Combine both systems for holistic view

```sql
CREATE VIEW INTELLIGENCE.UNIFIED_QUERY_ANALYTICS AS
SELECT
  -- Basic audit (from ANALYST_QUERY_LOG)
  l.query_id,
  l.user_id,
  l.question,
  l.generated_sql,
  l.success_flag,
  l.created_at,

  -- Performance (from AI_AGENT_GOVERNANCE)
  g.trace_id,
  g.total_duration_ms,
  g.input_tokens,
  g.output_tokens,
  g.estimated_cost_usd,
  g.cache_hit_rate_pct,

  -- Human feedback (from SEMANTIC_FEEDBACK)
  f.feedback_type,
  f.feedback_text,

  -- Quality scores (from TruLens - if available)
  q.answer_relevance_score,
  q.groundedness_score

FROM INTELLIGENCE.ANALYST_QUERY_LOG l
LEFT JOIN GOVERNANCE.AI_AGENT_GOVERNANCE g
  ON l.trace_id = g.trace_id  -- Link via trace_id
LEFT JOIN INTELLIGENCE.SEMANTIC_FEEDBACK f
  ON l.query_id = f.query_log_id
LEFT JOIN INTELLIGENCE.QUALITY_SCORES q
  ON l.query_id = q.query_id
WHERE l.created_at > DATEADD(day, -30, CURRENT_TIMESTAMP());
```

**Use for:** Weekly review queries that combine audit + performance + quality

---

## Article Update (Minimal)

Add this section to `subarticle_3_trust_layer_updated.md` (after "Part 5: Feedback Loops"):

```markdown
---

## Advanced: AI Observability Integration

For deep performance analysis and A/B testing, supplement the Trust Layer with:

### AI_AGENT_GOVERNANCE Table

Performance tracing with 37 metrics:
- Execution: trace_id, duration_ms, cache_hit_rate
- Cost: input_tokens, output_tokens, estimated_cost_usd
- Quality: execution_status, tools_used, planning_model

**When to use:**
- Cost optimization: "Which users consume most tokens?"
- Performance debugging: "Why is this query slow?"
- Tool usage analysis: "How often is CortexAnalyst called?"

**Link to article tables:**
```sql
-- Add trace_id to ANALYST_QUERY_LOG for deep-dive linking
ALTER TABLE INTELLIGENCE.ANALYST_QUERY_LOG
ADD COLUMN trace_id STRING;
```

### TruLens Quality Evaluation

LLM-based scoring (0-1) for:
- Answer relevance: Does SQL answer the question?
- Groundedness: Based on semantic model?
- Context relevance: Correct contexts retrieved?

**When to use:**
- A/B testing semantic model versions before deployment
- Validating critical questions pattern matching can't verify
- Quarterly deep quality audits

**When NOT to use:**
- Daily regression (use pattern matching - faster, free)
- Every user query (expensive, slow)

**See:** [AI Observability README](../../ai_observe/README.md)

---
```

**Keep article focused:** Trust Layer is practical, proven, lightweight. AI Observability is advanced, optional, selective.

---

## Summary

### Start Here (Week 1)
- Article Trust Layer components
- Pattern matching for eval seeds
- Human feedback collection

### Add When Needed (Week 2-3)
- AI_AGENT_GOVERNANCE for performance analysis
- LLM evaluation for A/B testing only

### Don't Overkill
- Don't run LLM eval on every query
- Don't duplicate logging unnecessarily
- Don't over-engineer before validation

### Success Metrics
- Pass rate >95% (pattern matching)
- Deployment confidence (A/B testing)
- Cost <$20/month
- CEO sleeps at night

---

**Questions?** Review tomorrow and decide which phase to implement first.
