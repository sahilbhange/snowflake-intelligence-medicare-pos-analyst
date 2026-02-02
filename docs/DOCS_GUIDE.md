# Complete File Guide

Detailed explanation of every documentation file in this project and what it covers.

---

## Implementation Guides (3 files)

### [getting-started.md](implementation/getting-started.md)
**Renamed from:** `execution_guide.md` (better reflects comprehensive nature)

**What it covers:**
- Complete step-by-step deployment from scratch
- Prerequisites (Snowflake CLI, Python, Make)
- All 9 deployment phases with verification steps
- Makefile target reference (`make demo`, `make setup`, etc.)
- Troubleshooting common deployment issues
- Post-deployment validation checklist

**Who needs it:**
- Data engineers deploying the project for the first time
- Anyone running `make demo` or step-by-step setup
- DevOps teams automating deployment

**When to use:**
- First-time setup
- Redeploying after major changes
- Troubleshooting deployment failures
- Understanding the full deployment pipeline

**Key sections:**
- Phase-by-phase deployment (data → setup → load → model → search → instrumentation → metadata → validation → tests)
- Make target reference table
- Verification SQL queries for each phase
- Rollback and reset procedures

---

### [data_model.md](implementation/data_model.md)
**What it covers:**
- Medallion architecture (RAW/CURATED/ANALYTICS)
- 6-schema pattern (RAW, CURATED, ANALYTICS, SEARCH, INTELLIGENCE, GOVERNANCE)
- Complete entity-relationship diagram (ERD) in Mermaid format
- Table-level documentation for each layer
- Grain definitions (provider + HCPCS)
- Relationship notes (HCPCS-to-device join caveats)

**Who needs it:**
- Data engineers understanding the schema design
- Analytics engineers writing queries
- New team members onboarding
- Anyone debugging data quality issues

**When to use:**
- Before writing queries
- When adding new tables or columns
- Understanding data lineage
- Explaining the architecture to stakeholders

**Key sections:**
- Medallion layer flow diagram
- DIM/FACT table definitions
- Primary/foreign key relationships
- Notes on demo simplifications (HCPCS-to-device mapping)

---

### [snowflake_intelligence_setup.md](implementation/snowflake_intelligence_setup.md)
**What it covers:**
- Snowsight UI configuration for Snowflake Intelligence
- Adding Cortex Analyst source (semantic model upload)
- Adding 3 Cortex Search services (HCPCS, Device, Provider)
- Testing query routing (Analyst vs Search)
- Permission configuration for multi-user access
- Troubleshooting UI and service issues

**Who needs it:**
- Data engineers configuring the UI after `make demo`
- Admins granting access to business users
- Anyone troubleshooting "No data" or "Service not found" errors

**When to use:**
- After completing [getting-started.md](implementation/getting-started.md) deployment
- When adding new users
- When semantic model or search services aren't showing in UI
- Configuring optional features (PDF search, query logging)

**Key sections:**
- Step-by-step UI configuration with screenshots
- Test queries for each source
- Permission grant SQL
- Troubleshooting table (5 common issues)
- Integration with getting-started guide

---

## Reference Documentation (4 files)

### [metric_catalog.md](reference/metric_catalog.md)
**What it covers:**
- Business definitions for ALL metrics in the semantic model
- Calculation formulas (SQL expressions)
- Data types, synonyms, expected ranges
- Use cases for each metric
- Edge cases and caveats (e.g., aggregation level, null handling)
- Filter reference table
- Data limitations and disclaimers

**Who needs it:**
- Business analysts understanding what metrics mean
- Analytics engineers writing semantic models
- QA teams validating metric accuracy
- Data stewards documenting business logic

**When to use:**
- Before adding new metrics to semantic model
- When users ask "What does this metric mean?"
- Validating AI-generated queries
- Writing documentation for stakeholders

**Key sections:**
- 9 volume metrics (claims, services, beneficiaries, suppliers)
- 3 payment metrics (payment, allowed, submitted charge)
- 6 derived metrics (ratios, per-claim/per-service calculations)
- Filter reference (geographic, HCPCS, behavioral)
- Data caveats section

**Example metric:**
```
PAYMENT_TO_ALLOWED_RATIO
- Definition: Ratio of Medicare payment to allowed amount
- Calculation: AVG(payment) / NULLIF(AVG(allowed), 0)
- Expected range: 0.7-0.9
- Edge case: Values > 1.0 indicate data quality issues
```

---

### [agent_guidance.md](reference/agent_guidance.md)
**What it covers:**
- Routing rules for AI agents (when to use Analyst vs Search)
- Signal detection (aggregation keywords, definition keywords)
- Hybrid query patterns (definition + metrics)
- Recommended filters for common queries
- Common pitfalls and fallback strategies
- Guardrails (don't return PII, don't make clinical recommendations)

**Who needs it:**
- ML engineers building AI routing logic
- Data scientists understanding query patterns
- Anyone debugging "wrong tool used" issues
- Developers integrating Snowflake Intelligence into apps

**When to use:**
- AI routes questions to wrong source
- Building custom routing logic
- Understanding why certain questions fail
- Writing prompts for users

**Key sections:**
- Routing decision table (keywords → tool)
- Hybrid pattern examples
- Filter recommendations (geographic, HCPCS, behavioral)
- Error handling table
- Guardrails checklist

**Example routing:**
```
"Top 10 states" → Analyst (aggregation keyword)
"What is E1390?" → Search (definition keyword)
"E1390 payment average" → Hybrid (definition + metric)
```

---

### [embedding_strategy.md](reference/embedding_strategy.md)
**What it covers:**
- Vector embedding strategy for RAG
- Chunking guidance (size, overlap, section preservation)
- Snowflake Arctic embedding model usage
- Vector similarity search SQL
- Complete RAG implementation (retrieve + generate)
- Hybrid search routing (vector vs keyword)
- Quality checks and optimization

**Who needs it:**
- ML engineers implementing RAG
- Data engineers setting up PDF search
- Anyone building semantic search features
- Developers optimizing vector storage costs

**When to use:**
- Implementing policy-based Q&A
- Adding document search capability
- Debugging poor retrieval quality
- Optimizing embedding storage

**Key sections:**
- Chunking strategy with Python examples
- Embedding generation SQL
- Vector similarity search patterns
- RAG pattern (retrieve context + LLM generate)
- Hybrid routing decision table
- Quality check queries
- Storage optimization tips

**Example code:**
```sql
-- This repo uses Cortex Search (no manual embedding columns by default).
-- See: sql/search/cortex_search_devices.sql
SELECT * FROM TABLE(
  SEARCH.DEVICE_SEARCH_SVC!SEARCH('oxygen concentrator', LIMIT => 10)
);
```

---

### [pdf_sources.md](reference/pdf_sources.md)
**What it covers:**
- CMS policy document references (Chapter 20, 23)
- Complete PDF extraction workflow (download → extract → chunk → load → embed → search)
- Python code for PDF text extraction
- Chunking code with section detection
- Snowflake loading with snowflake-connector-python
- Quality checks (chunk coverage, embedding coverage)
- Refresh process for quarterly CMS updates

**Who needs it:**
- Data engineers implementing PDF search
- ML engineers building RAG systems
- Anyone adding policy-based Q&A
- Developers maintaining document corpus

**When to use:**
- Setting up PDF search for first time
- Adding new policy documents
- Quarterly CMS manual updates
- Debugging poor policy question responses

**Key sections:**
- Source document table (URLs, page counts, update frequency)
- 6-step extraction workflow
- Complete Python examples (PyPDF2 + chunking)
- Snowflake loading code
- Quality check SQL
- Refresh procedures
- Troubleshooting guide

**Example workflow:**
```
1. Download CMS PDF (curl)
2. Extract text (PyPDF2)
3. Chunk text (800-1200 chars, 150 overlap)
4. Load to Snowflake (snowflake.connector)
5. Generate embeddings (CORTEX.EMBED_TEXT_1024)
6. Create search service (CREATE CORTEX SEARCH SERVICE)
```

---

## Governance & Lifecycle (6 files)

### [governance_feasibility.md](governance/governance_feasibility.md)
**What it covers:**
- Demo-first guidance: what to keep vs skip for the Medium walkthrough
- What’s automated (Make targets) vs what’s still manual (tasks/alerts)
- Upgrade path from demo governance to full governance templates

**Who needs it:**
- Anyone writing or running the Medium demo
- Anyone deciding whether governance content is “too much”

**When to use:**
- Before adding governance steps to an article or workshop
- When choosing between `make governance-demo` vs full governance scripts

---

### [data_dictionary.md](governance/data_dictionary.md)
**What it covers:**
- Dataset definitions, classifications, and lineage notes
- Schema architecture (RAW → CURATED → ANALYTICS → SEARCH/INTELLIGENCE/GOVERNANCE)
- Governance table references (metadata, profiling, quality checks)

**Who needs it:**
- Data stewards, analysts, or engineers looking for “what does this column mean?”

**When to use:**
- When validating metric definitions or interpreting fields
- When deciding what’s safe to share (classification context)

---

### [semantic_model_lifecycle.md](governance/semantic_model_lifecycle.md)
**What it covers:**
- Model lifecycle stages (Draft → Review → Published → Deprecated)
- Roles and responsibilities (Author, Reviewer, Steward, Analyst)
- Review cadence (weekly, monthly, quarterly)
- Promotion process between stages
- Semantic versioning (MAJOR.MINOR.PATCH)
- Quality gates before publishing
- Feedback integration workflow

**Who needs it:**
- Data stewards managing model versions
- Analytics engineers updating semantic models
- QA teams validating model changes
- Anyone publishing model updates

**When to use:**
- Before making model changes
- Publishing new semantic model version
- Deprecating old model versions
- Setting up review processes

**Key sections:**
- Lifecycle state diagram
- Promotion criteria (Draft→Review→Published)
- Version numbering rules
- Quality gate checklist
- Feedback triage process

**Example versioning:**
```
v1.0.0 → v1.1.0: Added new metric (MINOR bump)
v1.1.0 → v2.0.0: Renamed dimension (MAJOR bump)
v1.1.0 → v1.1.1: Fixed bug in calculation (PATCH bump)
```

---

### [semantic_model_changelog.md](governance/semantic_model_changelog.md)
**What it covers:**
- Version history for semantic model
- Changes log for each version (tables, dimensions, facts, metrics, filters, verified queries)
- Migration guides for breaking changes
- Known limitations documentation
- Future deprecation notices
- Reviewer sign-off table

**Who needs it:**
- Anyone understanding what changed between versions
- Data stewards tracking model evolution
- Users migrating from old to new versions
- Auditors reviewing change history

**When to use:**
- After publishing new version
- Before upgrading to new version
- Understanding why queries broke
- Compliance audits

**Key sections:**
- Version entries (one per release)
- Migration guide section
- Planned features (unreleased)
- Feedback log table
- Reviewer approval table

**Example entry:**
```markdown
## [1.1.0] - 2024-01-20

### Added
- PAYMENT_VARIANCE metric
- rental/purchase dimension synonyms

### Changed
- Updated model instructions for variance queries

### Known Issues
- Year-over-year trends not available (single snapshot)
```

---

### [semantic_publish_checklist.md](governance/semantic_publish_checklist.md)
**What it covers:**
- Pre-publish validation checklist (data quality, tests, structure, approval, documentation)
- Human validation gate (dashboard comparison, golden questions)
- Deployment steps with SQL/bash commands
- Rollback procedure
- Sign-off table for stakeholders
- Post-publish monitoring plan (24 hours, 1 week)

**Who needs it:**
- Data stewards publishing model updates
- QA teams validating before deployment
- Anyone following pre-publish process
- Auditors ensuring proper approval

**When to use:**
- Before every model deployment
- Creating sign-off documentation
- Rolling back failed deployments
- Post-deployment monitoring

**Key sections:**
- Pre-publish checklist (20+ items)
- Human validation requirements
- Deployment SQL
- Rollback procedure (<5 min)
- Sign-off table
- Monitoring schedule

**Validation criteria:**
```
✓ All tests pass
✓ 10 golden questions tested
✓ Match score ≥ 80% (simple), ≥ 65% (moderate)
✓ Domain expert approval
✓ Changelog updated
✓ No breaking changes (or migration documented)
```

---

### [human_validation_log.md](governance/human_validation_log.md)
**What it covers:**
- Demo shortcut section (15–30 min validation path)
- Dashboard checklist (3 reference dashboards)
- 10 golden questions with expected results
- AI vs human comparison log (with examples)
- Validation results summary table
- Follow-up action tracking
- Iteration log (version → changes → results)
- Weekly/monthly testing workflow

**Who needs it:**
- Data analysts building reference dashboards
- QA teams validating AI accuracy
- Data stewards tracking model quality
- Anyone debugging accuracy issues

**When to use:**
- After deploying new semantic model version
- Building reference dashboards
- Investigating AI response accuracy
- Weekly model quality reviews

**Key sections:**
- 10 golden questions (simple, moderate, complex)
- Example validation entries (3 detailed examples)
- Validation summary by complexity
- Follow-up action priorities
- Iteration log with pass rates
- Testing workflow (weekly/monthly)

**Example validation:**
```markdown
Question: "Top 5 states by claims"
Human: CA, TX, FL, NY, PA
AI: [Generated correct SQL and results]
Match Score: ✅ Exact (100%)
Notes: Perfect match, SQL optimal
```

---

## Diagrams (2 files)

### [datamodel.png](diagrams/datamodel.png)
**What it shows:**
- Complete entity-relationship diagram (ERD)
- All tables in medallion architecture
- Primary/foreign key relationships
- Dimension and fact table connections
- Grain notation (provider + HCPCS)

**Referenced in:**
- [data_model.md](implementation/data_model.md)
- [Medium Subarticle 2: Foundation Layer](../medium/claude/subarticle_2_foundation_layer.md)

---

### [cortex-search-rag.png](diagrams/cortex-search-rag.png)
**What it shows:**
- Intelligence layer architecture
- Cortex Analyst + Cortex Search + RAG flow
- Question routing logic
- Hybrid search pattern

**Referenced in:**
- [agent_guidance.md](reference/agent_guidance.md)
- [Medium Subarticle 1: Intelligence Layer](../medium/claude/subarticle_1_intelligence_layer.md)

---

## Archived Files

This repo does not keep an `docs/archive/` folder. If you’re looking for older scaffolds, use `git log -- docs/` to browse history.

## Supporting Files

### [README.md](README.md)
**What it covers:**
- Navigation hub for all documentation
- Quick start guide (3 steps)
- Documentation structure overview
- Common task workflows
- Recommended reading order (by role)
- File organization explanation

**Who needs it:**
- Everyone (first file to read)
- New team members onboarding
- Anyone looking for specific docs

**When to use:**
- First visit to docs folder
- Finding the right document
- Understanding doc organization

---

### [FILE_GUIDE.md](FILE_GUIDE.md) (this file)
**What it covers:**
- Detailed explanation of every single documentation file
- What each file contains
- Who needs each file
- When to use each file
- Key sections per file
- Example content from each file

**Who needs it:**
- Anyone wanting detailed understanding of docs
- New contributors understanding structure
- Anyone looking for specific content

**When to use:**
- Understanding what's in each file without opening it
- Choosing between similar docs
- Learning the documentation philosophy

---

## Quick Reference: Find the Right Doc

### "I need to deploy"
→ [getting-started.md](implementation/getting-started.md)

### "I need to understand the data"
→ [data_model.md](implementation/data_model.md) + [datamodel.png](diagrams/datamodel.png)

### "I need to configure the UI"
→ [snowflake_intelligence_setup.md](implementation/snowflake_intelligence_setup.md)

### "I need to know what metrics mean"
→ [metric_catalog.md](reference/metric_catalog.md)

### "I need to understand AI routing"
→ [agent_guidance.md](reference/agent_guidance.md)

### "I need to implement RAG"
→ [embedding_strategy.md](reference/embedding_strategy.md) + [pdf_sources.md](reference/pdf_sources.md)

### "I need to publish a model update"
→ [semantic_publish_checklist.md](governance/semantic_publish_checklist.md)

### "I need to track model versions"
→ [semantic_model_changelog.md](governance/semantic_model_changelog.md) + [semantic_model_lifecycle.md](governance/semantic_model_lifecycle.md)

### "I need to validate AI accuracy"
→ [human_validation_log.md](governance/human_validation_log.md)

---

## File Statistics

| Category | Files | Total Words (approx) |
|----------|-------|---------------------|
| Implementation | 3 | ~8,000 |
| Reference | 5 | ~12,000 |
| Governance | 6 | ~9,000 |
| Navigation | 3 | ~4,000 |
| **TOTAL** | **17** | **~33,000** |

Plus:
- 2 diagrams (PNG)
- 4 Medium articles (~35,500 words)

**Grand total documentation:** ~67,500 words across 20 files
