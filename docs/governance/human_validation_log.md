# Human Validation Log

Track analyst-built dashboards, golden questions, and AI validation results for the DMEPOS semantic model.
---

## Navigation

| Want This | See This |
|-----------|----------|
| 📖 **Trust Layer Concepts** | [Subarticle 3: The Trust Layer](../../medium/claude/subarticle_3_trust_layer.md) |
| 💾 **Validation Framework SQL** | [SQL: Validation Framework](../../sql/intelligence/validation_framework.sql) |
| 💾 **Instrumentation SQL** | [SQL: Instrumentation](../../sql/intelligence/instrumentation.sql) |
| 📚 **Lifecycle Management** | [Semantic Model Lifecycle](semantic_model_lifecycle.md) |

---


---

> **📖 See Medium:** Learn validation strategies in [Subarticle 3: The Trust Layer](../../medium/claude/subarticle_3_trust_layer.md)
## Overview

This log captures human-in-the-loop validation to ensure Snowflake Intelligence (Cortex Analyst) produces accurate, reliable results.

**Goal:** 80%+ match rate for simple questions, 65%+ for moderate complexity.

---

## Demo Shortcut (15–30 minutes)

If you’re following the Medium hands-on demo, you can keep human validation lightweight:

1. Build **one** Snowsight dashboard (Provider or HCPCS) as a “ground truth” reference.
2. Test **5 questions** in Cortex Analyst (3 simple, 2 moderate).
3. Record only:
   - the question
   - the SQL generated (if available)
   - whether the result “looks right”

Use the full sections below when you want a repeatable validation process for production.

## Dashboard Checklist

Build 3 reference dashboards in Snowsight to serve as ground truth for AI validation.

### Dashboard 1: Provider Analysis
- [ ] **Created:** YYYY-MM-DD
- [ ] **Owner:** Data Analyst Name
- [ ] **Key Metrics:**
  - Total providers by state
  - Top 10 specialties by claim volume
  - Claims per provider distribution
- [ ] **Link:** [Snowsight Dashboard URL]
- [ ] **Status:** ✅ Complete

### Dashboard 2: HCPCS Analysis
- [ ] **Created:** YYYY-MM-DD
- [ ] **Owner:** Data Analyst Name
- [ ] **Key Metrics:**
  - Top 20 HCPCS codes by volume
  - Rental vs purchase breakdown
  - Average payment by code category
- [ ] **Link:** [Snowsight Dashboard URL]
- [ ] **Status:** ⏳ In progress

### Dashboard 3: Geographic Breakdown
- [ ] **Created:** YYYY-MM-DD
- [ ] **Owner:** Data Analyst Name
- [ ] **Key Metrics:**
  - State rankings (claims, payment, services)
  - Payment-to-allowed ratio by state
  - Top states for specific HCPCS codes
- [ ] **Link:** [Snowsight Dashboard URL]
- [ ] **Status:** ⏳ Pending

---

## Golden Questions (10)

Questions with known correct answers for regression testing.

| Question ID | Complexity | Question | Expected Result | Last Tested | Status |
|-------------|------------|----------|-----------------|-------------|--------|
| GQ01 | Simple | Top 5 states by total claims | CA, TX, FL, NY, PA | 2024-01-XX | ✅ Pass |
| GQ02 | Simple | Top 3 HCPCS codes by claim volume | E1390, A4253, E0431 | 2024-01-XX | ✅ Pass |
| GQ03 | Simple | Total unique providers | ~50,000 (from DIM_PROVIDER) | 2024-01-XX | ✅ Pass |
| GQ04 | Moderate | Average Medicare payment per service | $XX.XX (from semantic model) | 2024-01-XX | ✅ Pass |
| GQ05 | Moderate | Rental vs purchase claim volume | Y: XXX, N: XXX | 2024-01-XX | ⚠️ Partial |
| GQ06 | Moderate | States with highest avg payment | Top 10 list | 2024-01-XX | ⏳ Pending |
| GQ07 | Moderate | Top provider specialties | Internal Medicine, NP, Family | 2024-01-XX | ✅ Pass |
| GQ08 | Complex | Payment-to-allowed ratio by state | State-level ratios (0.8-0.9) | 2024-01-XX | ⚠️ Partial |
| GQ09 | Complex | Provider efficiency by specialty | Claims per provider by specialty | 2024-01-XX | ⏳ Pending |
| GQ10 | Complex | Highest payment variance E-codes | Top 10 E-codes with HAVING filter | 2024-01-XX | ❌ Fail |

---

## AI vs Human Comparison Log

Track AI responses against human-created dashboard results.

### Example Entry 1
**Date:** 2024-01-15
**Question ID:** GQ01
**Question:** "What are the top 5 states by total claims?"

**Human Result (Dashboard 1):**
```
1. California - 1,245,678 claims
2. Texas - 987,543 claims
3. Florida - 876,234 claims
4. New York - 765,432 claims
5. Pennsylvania - 654,321 claims
```

**AI Result (Cortex Analyst):**
```sql
-- Generated SQL
SELECT provider_state, SUM(total_supplier_claims) AS total_claims
FROM ANALYTICS.FACT_DMEPOS_CLAIMS
GROUP BY provider_state
ORDER BY total_claims DESC
LIMIT 5;
```

**Match Score:** ✅ Exact (100%)
**SQL Quality:** Correct
**Notes:** Perfect match. SQL is optimal.

---

### Example Entry 2
**Date:** 2024-01-15
**Question ID:** GQ05
**Question:** "Compare rental vs purchase claim volumes"

**Human Result (Dashboard 2):**
```
Rental (Y): 456,789 claims
Purchase (N): 1,234,567 claims
```

**AI Result (Cortex Analyst):**
```sql
-- Generated SQL
SELECT supplier_rental_indicator, SUM(total_supplier_claims) AS total_claims
FROM ANALYTICS.FACT_DMEPOS_CLAIMS
GROUP BY supplier_rental_indicator;
```

**Match Score:** ⚠️ Partial (80%)
**SQL Quality:** Correct
**Notes:** Numbers match, but AI didn't provide interpretation (which is rental vs purchase). Need to add synonyms to semantic model.

**Action Item:** Add `rental` and `purchase` as dimension synonyms in semantic model.

---

### Example Entry 3
**Date:** 2024-01-16
**Question ID:** GQ10
**Question:** "Which E-codes have the highest payment variance?"

**Human Result (Dashboard 2):**
```
1. E1390 - stddev $15.23
2. E0431 - stddev $12.45
...
```

**AI Result (Cortex Analyst):**
```
Error: "I cannot calculate variance. Please refine your question."
```

**Match Score:** ❌ Fail (0%)
**SQL Quality:** Not generated
**Notes:** AI doesn't recognize "variance" as STDDEV. Semantic model lacks variance metric.

**Action Items:**
1. Add `PAYMENT_VARIANCE` metric to semantic model
2. Add synonyms: "variance", "variability", "standard deviation"
3. Retest after update

---

## Validation Results Summary

### By Complexity

| Complexity | Total | Pass | Partial | Fail | Pass Rate |
|------------|-------|------|---------|------|-----------|
| Simple | 3 | 3 | 0 | 0 | 100% ✅ |
| Moderate | 4 | 2 | 2 | 0 | 50% ⚠️ |
| Complex | 3 | 0 | 1 | 2 | 0% ❌ |
| **TOTAL** | **10** | **5** | **3** | **2** | **50%** |

**Target:** 80% pass rate for simple, 65% for moderate, 50% for complex.

**Status:** ⚠️ Simple: ✅ | Moderate: ⚠️ | Complex: ❌

---

## Follow-up Actions

Track improvements based on validation results.

> **💾 Track in SQL:** Store action items in [validation_framework.sql](../../sql/intelligence/validation_framework.sql) and [instrumentation.sql](../../sql/intelligence/instrumentation.sql)



### High Priority
- [ ] **Action 1:** Add `PAYMENT_VARIANCE` metric to semantic model (for GQ10)
- [ ] **Action 2:** Add `rental` and `purchase` synonyms for `supplier_rental_indicator` (for GQ05)
- [ ] **Action 3:** Expand model instructions with variance calculation examples

### Medium Priority
- [ ] **Action 4:** Add more verified queries for complex aggregations
- [ ] **Action 5:** Create eval set entries for failed questions
- [ ] **Action 6:** Document edge cases in metric catalog

### Low Priority
- [ ] **Action 7:** Build Dashboard 3 (Geographic Breakdown)
- [ ] **Action 8:** Add 5 more golden questions for edge cases
- [ ] **Action 9:** Schedule monthly validation reviews

---

## Iteration Log

Track semantic model updates and retest results.

| Date | Version | Changes | Retest Results |
|------|---------|---------|----------------|
| 2024-01-15 | v1.0.0 | Initial release | 5/10 pass (50%) |
| 2024-01-20 | v1.1.0 | Added `PAYMENT_VARIANCE` metric | 6/10 pass (60%) |
| 2024-01-22 | v1.1.1 | Added rental/purchase synonyms | 7/10 pass (70%) |

> **💾 See SQL:** Track iterations in [validation_framework.sql](../../sql/intelligence/validation_framework.sql)

---

## Feedback Collection

Log user feedback from Snowflake Intelligence sessions.

### Sample Feedback Entry

**Date:** 2024-01-18
**User:** john.doe@example.com
**Question:** "Top providers in California"
**Was Helpful?** ✅ Yes
**Feedback:** "Results were accurate, but wanted to see specialty breakdown too."
**Action:** Add follow-up suggestion in model instructions

---

## Related Documentation

- [Semantic Model Lifecycle](semantic_model_lifecycle.md) - Version management
- [Semantic Model Changelog](semantic_model_changelog.md) - Version history
- [Publish Checklist](semantic_publish_checklist.md) - Pre-publish validation
- [Metric Catalog](../reference/metric_catalog.md) - Business metric definitions

---

## Testing Workflow

### Weekly Review Process

1. **Monday:** Review last week's query logs
2. **Tuesday:** Identify new edge cases or failure patterns
3. **Wednesday:** Update golden questions or semantic model
4. **Thursday:** Retest all golden questions
5. **Friday:** Document results and plan next iteration

> **💾 Logs Located In:** [instrumentation.sql](../../sql/intelligence/instrumentation.sql) for query logging, [validation_framework.sql](../../sql/intelligence/validation_framework.sql) for test results

### Monthly Deep Dive

1. Build/update reference dashboards
2. Validate AI results against all dashboards
3. Update semantic model based on feedback
4. Run full regression suite (all golden questions)
5. Update this log with findings

---

## Template for New Validation Entry

```markdown
### Validation Entry: [Question ID]
**Date:** YYYY-MM-DD
**Question ID:** GQXX
**Question:** "Your question here"

**Human Result:**
[Paste from dashboard or manual query]

**AI Result:**
[Paste AI-generated SQL and results]

**Match Score:** ✅/⚠️/❌ (XX%)
**SQL Quality:** Correct / Suboptimal / Incorrect
**Notes:** [Analysis of discrepancies]

**Action Items:**
1. [Specific improvement needed]
2. [Follow-up task]
```
