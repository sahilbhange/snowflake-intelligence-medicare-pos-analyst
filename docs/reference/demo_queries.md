# Demo Queries: Showcasing Snowflake Intelligence

Smart questions designed to demonstrate Cortex Analyst, Cortex Search, and intelligent routing.

---

## Demo Flow: The 5-Minute Walkthrough

### Act 1: The Discovery (Pure Search)
*"I don't know what I'm looking at yet"*

#### Q1: What is HCPCS code E1390?
**Route:** Cortex Search (HCPCS_SEARCH_SVC)
**Why this works:** Zero structured data needed - pure lookup
**Expected answer:** "OXYGEN CONCENTRATOR, PORTABLE, BATTERY OPERATED"
**Wow factor:** Instant definition without writing SQL

#### Q2: Find oxygen concentrator devices
**Route:** Cortex Search (DEVICE_SEARCH_SVC)
**Why this works:** Semantic search across device descriptions
**Expected answer:** List of FDA GUDID devices matching "oxygen concentrator"
**Wow factor:** Finds devices by meaning, not exact keyword match

---

### Act 2: The Analytics (Pure Analyst)
*"Now I want numbers"*

#### Q3: What are the top 5 states by total Medicare claims?
**Route:** Cortex Analyst
**Why this works:** Classic aggregation + ranking
**Expected SQL pattern:** `GROUP BY provider_state ORDER BY SUM(total_supplier_claims) DESC LIMIT 5`
**Expected top states:** CA, TX, FL, NY, PA (high-population states)
**Wow factor:** Natural language → SQL → Results in seconds

#### Q4: Show me average Medicare payment for E1390
**Route:** Cortex Analyst
**Why this works:** Metric extraction with filter
**Expected SQL pattern:** `WHERE hcpcs_code = 'E1390' ... AVG(avg_supplier_medicare_payment)`
**Expected answer:** ~$50-150 per claim (oxygen concentrator rental)
**Wow factor:** Combines HCPCS knowledge with analytics

#### Q5: Compare rental vs purchase equipment by total claims
**Route:** Cortex Analyst
**Why this works:** Comparison across dimension
**Expected SQL pattern:** `GROUP BY supplier_rental_indicator`
**Expected insight:** Rentals typically dominate for durable equipment
**Wow factor:** Business insight from simple English

---

### Act 3: The Hybrid Magic (Search + Analyst)
*"Now combine them"*

#### Q6: What are oxygen concentrators and how much does Medicare spend on them?
**Route:** Hybrid (Search → Analyst)
**Step 1 (Search):** Find HCPCS codes for oxygen concentrators (E1390, E1391, E1392)
**Step 2 (Analyst):** SUM Medicare payments WHERE hcpcs_code IN ('E1390','E1391','E1392')
**Expected answer:** Definition + $XX million total spend
**Wow factor:** Agent autonomously chains tools without prompting

#### Q7: Find wheelchair devices, then show me top 5 states by wheelchair claims
**Route:** Hybrid (Search → Analyst)
**Step 1 (Search):** Search device catalog for "wheelchair" → get HCPCS codes
**Step 2 (Analyst):** Filter claims by those codes, group by state, rank
**Expected insight:** Geographic distribution of wheelchair usage
**Wow factor:** Complex question requiring 2 different data sources

---

### Act 4: The Business Question (Advanced Routing)
*"Real-world executive questions"*

#### Q8: Which providers in California have the highest volume for diabetes supplies?
**Route:** Cortex Analyst (with semantic understanding)
**Complexity:** Needs to understand "diabetes supplies" → RBCS category or HCPCS pattern
**Expected SQL:** Filter CA + diabetes-related HCPCS + rank by claim volume
**Wow factor:** Domain-aware semantic model understands clinical categories

#### Q9: What specialty has the most DMEPOS providers and what's their average payment?
**Route:** Cortex Analyst (multi-metric)
**Complexity:** Group by specialty, count providers, average payment
**Expected answer:** Internal Medicine or Family Practice with $XX avg
**Wow factor:** Two metrics in one natural language question

#### Q10: Show me the top 5 most expensive HCPCS codes by average submitted charge
**Route:** Cortex Analyst
**Complexity:** Ranking by financial metric
**Expected insight:** Complex equipment (power wheelchairs, ventilators) at top
**Business value:** Identifies high-cost areas for review
**Wow factor:** Financial insight without knowing column names

---

## Advanced Demo Questions

### Geographic Intelligence

#### Q11: Which ZIP codes in Texas have the most suppliers?
**Route:** Cortex Analyst
**Pattern:** Geographic drill-down
**Expected:** Major metro areas (Houston, Dallas, Austin ZIPs)

#### Q12: Compare average Medicare allowed amounts between California and Texas
**Route:** Cortex Analyst
**Pattern:** State-level comparison
**Expected insight:** Geographic payment variation

### Clinical Pattern Analysis

#### Q13: What's the split between rental and purchase for equipment codes (E-codes)?
**Route:** Cortex Analyst
**Pattern:** Category + dimension analysis
**Business value:** Understanding rental vs purchase patterns

#### Q14: Top 5 RBCS categories by total beneficiaries served
**Route:** Cortex Analyst
**Pattern:** Clinical category ranking
**Business value:** Identifies most-needed equipment types

### Provider Intelligence

#### Q15: Find endocrinologists in New York
**Route:** Cortex Search (PROVIDER_SEARCH_SVC)
**Pattern:** Provider directory search by specialty + location
**Expected:** List of providers matching criteria

#### Q16: Show me providers with more than 100 distinct beneficiaries
**Route:** Cortex Analyst
**Pattern:** Provider filtering by volume
**Business value:** High-volume provider identification

---

## Gotcha Questions (Test Agent Routing)

### Q17: What does "DMEPOS" stand for?
**Expected route:** Search (general knowledge or PDF if policy docs loaded)
**Fallback:** "Durable Medical Equipment, Prosthetics, Orthotics, and Supplies"
**Tests:** Agent's ability to handle definition questions

### Q18: Show me all the data
**Expected response:** Clarification question
**Agent should ask:** "What specific data? Options: provider summary, HCPCS analysis, geographic breakdown"
**Tests:** Ambiguity handling

### Q19: What's the year-over-year growth in claims?
**Expected response:** Limitation explanation
**Agent should say:** "This dataset is a single snapshot without temporal dimension"
**Tests:** Scope awareness

### Q20: Which oxygen concentrator brand is most reliable?
**Expected response:** Limitation explanation
**Agent should say:** "Reliability data not available in CMS claims. Dataset contains billing/payment data only"
**Tests:** Guardrails against clinical recommendations

---

## Demo Script for Videos

### 30-Second Quick Demo (Act 1 + Act 2)
```
[Type] "What is HCPCS E1390?"
[Result] Oxygen concentrator definition appears

[Type] "Top 5 states by Medicare claims"
[Result] CA, TX, FL, NY, PA with claim counts

[Type] "Average payment for E1390"
[Result] $XX.XX
```

### 60-Second Intelligence Demo (Act 3)
```
[Type] "What are oxygen concentrators and how much does Medicare spend on them?"
[Watch] Agent routes to Search → gets definition
[Watch] Agent routes to Analyst → calculates total spend
[Result] Combined answer with definition + $XX million spend

[Type] "Find wheelchair devices then show top 5 states by wheelchair claims"
[Watch] Multi-step reasoning in action
[Result] Device list + state rankings
```

### 90-Second Executive Demo (All Acts)
```
[Setup] "I'm a VP of Analytics. I got this email asking about diabetes supplies..."

[Q1] "Which providers in California have highest volume for diabetes supplies?"
[Show] State filter + clinical category understanding

[Q2] "What are the most expensive equipment types we're paying for?"
[Show] Financial ranking

[Q3] "Compare rental vs purchase claims"
[Show] Business insight from dimension

[Finish] "All without writing SQL or waiting for data team"
```

---

## Expected Results Table

| Question | Tool(s) | Response Time | Complexity |
|----------|---------|---------------|------------|
| Q1: What is E1390 | Search | <1s | Low |
| Q2: Find oxygen concentrators | Search | <2s | Low |
| Q3: Top 5 states | Analyst | 2-5s | Low |
| Q4: Avg payment E1390 | Analyst | 2-5s | Low |
| Q5: Rental vs purchase | Analyst | 2-5s | Medium |
| Q6: O2 definition + spend | Hybrid | 5-10s | High |
| Q7: Wheelchair devices + states | Hybrid | 5-10s | High |
| Q8: CA diabetes providers | Analyst | 3-7s | Medium |
| Q9: Specialty metrics | Analyst | 3-7s | Medium |
| Q10: Most expensive HCPCS | Analyst | 2-5s | Low |

---

## Routing Cheat Sheet

### 🔍 Use Search When You See:
- "What is..."
- "Define..."
- "Find..."
- "Tell me about..."
- "Search for..."
- "Look up..."

### 📊 Use Analyst When You See:
- "Top X..."
- "Average..."
- "Total..."
- "How many..."
- "Compare..."
- "Show me breakdown..."

### 🔀 Use Hybrid When You See:
- "What is X **and** how much..."
- "Find Y **then** show..."
- Definition + metrics in same question
- Entity lookup + aggregation

---

## Testing Checklist

Before demo, verify:
- [ ] All search services deployed (HCPCS, Device, Provider)
- [ ] Semantic model uploaded and active
- [ ] Agent created and has access to all tools
- [ ] Test Q1-Q5 returns results in <5s each
- [ ] Test Q6-Q7 shows multi-step reasoning
- [ ] Fact table has data (SELECT COUNT(*) FROM FACT_DMEPOS_CLAIMS should be >0)

---

## Troubleshooting

### Agent returns "No results"
- Check: Is FACT_DMEPOS_CLAIMS populated?
- Check: Are HCPCS codes in data matching search terms?
- Fix: Run `make model` to rebuild analytics layer

### Search returns nothing
- Check: Is search service created? `SHOW CORTEX SEARCH SERVICES IN SEARCH;`
- Check: Is corpus table populated? `SELECT COUNT(*) FROM SEARCH.HCPCS_CORPUS;`
- Fix: Run `make search` to rebuild search services

### Analyst generates wrong SQL
- Check: Is semantic model up to date?
- Check: Column names match YAML definitions?
- Fix: Re-upload semantic model YAML, run `make agent` to refresh

---

## Pro Tips for Live Demo

1. **Pre-warm queries:** Run each question once before demo to cache results
2. **Have backup:** Keep Snowsight worksheet with SQL ready if agent fails
3. **Explain routing:** Point out "Agent is now using Search..." vs "Agent is querying data..."
4. **Show the SQL:** For Analyst queries, show generated SQL to prove it's not magic
5. **Handle failures gracefully:** If a query fails, explain why (good teaching moment)

---

## One-Liner Questions for Quick Demos

**Simplest (30s demo):**
1. "What is HCPCS E1390?"
2. "Top 5 states by claims"
3. "Average Medicare payment for E1390"

**Impressive (60s demo):**
1. "What are oxygen concentrators and how much does Medicare spend?"
2. "Find wheelchair devices then show top states"
3. "Compare rental vs purchase claims"

**Executive (90s demo):**
1. "Top 5 most expensive equipment by average charge"
2. "Which California providers have highest diabetes supply volume?"
3. "Show me specialty breakdown with provider counts and avg payments"

---

**Last Updated:** 2026-02-01
**Status:** Ready for demo recording
