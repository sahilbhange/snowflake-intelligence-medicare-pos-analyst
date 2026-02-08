# AI Observability Migration Checklist

**From manual pattern matching to automated LLM-based evaluation.**

---

## Phase 1: Setup (Week 1)

### Day 1: Snowflake Configuration
- [ ] Run `setup.sql` in Snowflake
  ```sql
  USE ROLE ACCOUNTADMIN;
  source ai_observe/setup.sql;
  ```
- [ ] Verify event table created
  ```sql
  SHOW EVENT TABLES IN SCHEMA INTELLIGENCE;
  ```
- [ ] Confirm privileges granted
  ```sql
  SHOW GRANTS TO ROLE ANALYST_ROLE;
  ```

### Day 2: Python Environment
- [ ] Install TruLens SDK
  ```bash
  pip install trulens-core==2.1.2
  pip install trulens-connectors-snowflake==2.1.2
  pip install trulens-providers-cortex==2.1.2
  ```
- [ ] Update Snowpark Python (if needed)
  ```bash
  pip install snowflake-snowpark-python --upgrade
  ```
- [ ] Test connection
  ```python
  from implementation_code import initialize_session
  session, tru = initialize_session()
  print("✓ Connected")
  ```

### Day 3: Semantic Model Metadata
- [ ] Populate `SEMANTIC_MODEL_METADATA` table
  ```sql
  SELECT COUNT(*) FROM INTELLIGENCE.SEMANTIC_MODEL_METADATA;
  -- Should return >= 5 rows
  ```
- [ ] Add all measures/dimensions from YAML
- [ ] Include synonyms for common phrasings

### Day 4-5: POC Testing
- [ ] Instrument single eval seed
- [ ] Generate trace in event table
- [ ] Verify metrics calculated
  ```sql
  SELECT * FROM INTELLIGENCE.SEMANTIC_ANALYST_QUALITY LIMIT 1;
  ```

---

## Phase 2: Parallel Validation (Week 2-3)

### Week 2: Side-by-Side Comparison

**Run both systems on same eval seeds:**

| Eval Seed | Manual Pattern Match | AI Observability Score |
|-----------|---------------------|------------------------|
| Top 5 states | ✓ (pattern matched) | 0.92 relevance, 0.88 groundedness |
| Average payment | ✗ (no pattern) | 0.76 relevance, 0.82 groundedness |
| Total suppliers in CA | ✓ (pattern matched) | 0.95 relevance, 0.91 groundedness |

**Tasks:**
- [ ] Run all 20 eval seeds through both systems
- [ ] Document discrepancies
- [ ] Investigate cases where manual=PASS but AI score <0.7
- [ ] Investigate cases where manual=FAIL but AI score >0.8

### Week 3: Tune Evaluation Prompts

**Adjust LLM judge if needed:**
```python
# If LLM judge is too strict
cortex_provider = Cortex(session, model_engine='llama3.1-70b', temperature=0.3)

# If LLM judge is too lenient
cortex_provider = Cortex(session, model_engine='llama3.1-70b', temperature=0.1)
```

- [ ] Compare AI scores with human feedback
  ```sql
  SELECT
      answer_relevance_score,
      feedback_type,
      COUNT(*) AS count
  FROM INTELLIGENCE.UNIFIED_QUERY_ANALYTICS
  WHERE feedback_type IS NOT NULL
  GROUP BY 1, 2
  ORDER BY 1 DESC;
  ```
- [ ] Identify score thresholds
  - High quality: >0.85
  - Medium quality: 0.70-0.85
  - Low quality: <0.70

---

## Phase 3: Cutover (Week 4)

### Before Cutover: Validation Gate

**Must pass all checks:**
- [ ] AI Observability coverage: 100% of eval seeds instrumented
- [ ] Correlation with human feedback: >80% agreement
- [ ] Event table storage: <$20/month
- [ ] Compute cost: <$100/month for nightly regression
- [ ] Latency acceptable: <5s per eval seed

### Cutover Day

**Morning (9 AM):**
- [ ] Backup existing `SEMANTIC_TEST_RESULTS` table
  ```sql
  CREATE TABLE INTELLIGENCE.SEMANTIC_TEST_RESULTS_BACKUP AS
  SELECT * FROM INTELLIGENCE.SEMANTIC_TEST_RESULTS;
  ```
- [ ] Update nightly regression script to use AI Observability
- [ ] Test run on 5 eval seeds

**Afternoon (2 PM):**
- [ ] Enable full nightly regression (all 20 seeds)
- [ ] Monitor for errors
- [ ] Verify metrics in `DAILY_QUALITY_METRICS` view

**Evening (5 PM):**
- [ ] Review first full run
- [ ] Check alerts triggered correctly
- [ ] Confirm no data loss

### Next Day
- [ ] Review overnight regression results
- [ ] Compare with previous manual results
- [ ] Fix any discrepancies

---

## Phase 4: Optimize (Week 5+)

### Week 5: Dashboard & Reporting
- [ ] Build Snowsight dashboard
  - Quality trend (7-day moving average)
  - Pass rate by model version
  - Low-quality questions table
  - Drift alerts

### Week 6: Automated Actions
- [ ] Enable automated alerts
  ```sql
  ALTER TASK INTELLIGENCE.DAILY_QUALITY_CHECK RESUME;
  ALTER TASK INTELLIGENCE.WEEKLY_DRIFT_CHECK RESUME;
  ```
- [ ] Set up Slack/email notifications
- [ ] Create runbook for quality incidents

### Week 7: A/B Testing Workflow
- [ ] Document A/B testing procedure
- [ ] Run first A/B test (v1.3.2 vs v1.4.0)
- [ ] Use comparison to inform deployment decision

### Week 8: Feedback Loop
- [ ] Auto-promote high-quality questions to eval seeds
  ```sql
  -- Questions with >10 asks and >0.8 avg quality
  INSERT INTO INTELLIGENCE.ANALYST_EVAL_SET
  SELECT ... FROM high_quality_questions;
  ```
- [ ] Weekly review process
  - Find low-quality questions
  - Update semantic model descriptions/synonyms
  - Rerun eval seeds to confirm improvement

---

## Rollback Plan

**If AI Observability fails:**

### Immediate Rollback (5 minutes)
```sql
-- Revert nightly regression to manual pattern matching
-- (Keep old script in git for this reason)
```

### Investigate Issues
- Check event table for errors
- Review LLM judge responses
- Compare with human feedback
- Adjust prompts or thresholds

### Re-deploy
- Fix identified issues
- Test on 5 eval seeds
- Gradual rollout (20% → 50% → 100%)

---

## Success Metrics

### Quality Metrics
| Metric | Target | Current (Manual) | AI Observability |
|--------|--------|------------------|------------------|
| Pass rate | >90% | 72% | TBD |
| False positives | <5% | ~15% | TBD |
| False negatives | <5% | ~10% | TBD |

### Efficiency Metrics
| Metric | Before | After |
|--------|--------|-------|
| Time spent on validation | 10 hrs/week | 2 hrs/week |
| MTTR for quality issues | 3 days | <1 day |
| Cost | $52k/year (labor) | $2.5k/year (compute) |

### Business Metrics
| Metric | Target |
|--------|--------|
| CEO finds bugs before team | 0 incidents |
| User satisfaction with AI answers | >85% |
| Semantic model update frequency | 2x/month |

---

## Common Issues & Solutions

### Issue: Event table not receiving events
**Solution:**
```sql
-- Verify privileges
SHOW GRANTS TO ROLE ANALYST_ROLE;

-- Check event table config
DESCRIBE EVENT TABLE INTELLIGENCE.AI_OBSERVABILITY_EVENTS;

-- Test manual insert
INSERT INTO INTELLIGENCE.AI_OBSERVABILITY_EVENTS ...;
```

### Issue: LLM judge scores always 0.5
**Solution:**
- Check Cortex model availability
- Verify model name spelling (`llama3.1-70b` not `llama3.1`)
- Increase timeout for model inference

### Issue: Costs higher than expected
**Solution:**
- Reduce eval seed frequency (nightly → weekly)
- Sample 20% of production queries instead of 100%
- Use smaller LLM judge (`mistral-7b` instead of `llama3.1-70b`)

### Issue: Scores don't match human feedback
**Solution:**
```sql
-- Find discrepancies
SELECT
    user_question,
    answer_relevance_score,
    feedback_type
FROM INTELLIGENCE.UNIFIED_QUERY_ANALYTICS
WHERE (answer_relevance_score > 0.8 AND feedback_type = 'accuracy')
   OR (answer_relevance_score < 0.7 AND feedback_type IS NULL);

-- Tune thresholds based on correlation
```

---

## Team Communication

### Stakeholder Update Template

**Subject: AI Quality Validation - Week X Update**

**Progress:**
- ✓ Setup complete
- ✓ POC tested on 5 eval seeds
- ⬜ Full cutover (scheduled for [date])

**Metrics:**
- Pass rate: X%
- Avg quality score: 0.XX
- Low-quality questions identified: X

**Next Steps:**
- Enable automated alerts
- Build Snowsight dashboard
- Run first A/B test

**Risks:**
- None / [describe if any]

---

## Final Checklist Before Production

- [ ] All eval seeds instrumented
- [ ] Event table receiving data
- [ ] Metrics calculated correctly
- [ ] Alerts configured
- [ ] Dashboard built
- [ ] Team trained on new system
- [ ] Runbook documented
- [ ] Rollback plan tested
- [ ] Stakeholders informed
- [ ] Go/no-go decision made

---

**Once all boxes checked: You're ready to ship! 🚀**
