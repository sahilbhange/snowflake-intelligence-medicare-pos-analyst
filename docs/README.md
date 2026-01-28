# Documentation

Complete guide to the Snowflake Intelligence Medicare POS Analyst project.

---
---

## 🗺️ How to Use This Documentation

**Learning path:** Medium Article → Docs → SQL Code

```
Medium Article (Concepts)
    ↓ "Want quick reference?"
Docs (Parameters & Config)
    ↓ "Ready to implement?"
SQL Files (Working Code)
```

- **Start with Medium** for deep understanding (20-25 min reads)
- **Jump to Docs** for quick configuration lookups (2-5 min)
- **Use SQL files** for copy-paste ready code (production tested)

Each doc links to the Medium article and SQL implementation. Each SQL file links to the docs and Medium for context.

---


## 🚀 Quick Start

**New to this project?** Start here:

1. [Getting Started](implementation/getting-started.md) - Step-by-step deployment (recommended first read)
2. [Data Model](implementation/data_model.md) - Understand the schema architecture
3. [Snowflake Intelligence Setup](implementation/snowflake_intelligence_setup.md) - Configure the UI

**Estimated time:** 2-3 hours for full deployment

---

## 📂 Documentation Structure

### Implementation Guides
Deployment, configuration, and setup instructions.

| Document | Description | When to Use |
|----------|-------------|-------------|
| [Getting Started](implementation/getting-started.md) | Complete step-by-step deployment guide with Makefile targets | First-time setup or full redeploy |
| [Data Model](implementation/data_model.md) | ERD, schema architecture, and table relationships | Understanding the data structure |
| [Snowflake Intelligence Setup](implementation/snowflake_intelligence_setup.md) | Configure Snowsight UI for Cortex services | After running `make demo` |

---

### Reference Documentation
Technical specifications, metrics, and AI guidance.

| Document | Description | When to Use |
|----------|-------------|-------------|
| [Metric Catalog](reference/metric_catalog.md) | Business metric definitions, calculations, and edge cases | Understanding available metrics |
| [Agent Guidance](reference/agent_guidance.md) | AI routing rules (Analyst vs Search) | Debugging query routing |
| [Cortex Agent Creation](reference/cortex_agent_creation.md) | Building multi-tool agents with SQL | Creating new agents or understanding agent architecture |
| [Embedding Strategy](reference/embedding_strategy.md) | Vector embeddings, RAG patterns, PDF chunking guidance | Implementing semantic search and PDF search services |
| [PDF Sources](reference/pdf_sources.md) | CMS policy documents for RAG | Adding policy-based Q&A |

---

### Governance & Lifecycle
Model versioning, quality checks, and validation.

| Document | Description | When to Use |
|----------|-------------|-------------|
| [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md) | Version management process (Draft → Review → Published) | Managing model changes |
| [Semantic Model Changelog](governance/semantic_model_changelog.md) | Version history and migration notes | Tracking what changed |
| [Publish Checklist](governance/semantic_publish_checklist.md) | Pre-publish validation steps | Before deploying model updates |
| [Human Validation Log](governance/human_validation_log.md) | Golden questions, dashboard validation, AI testing | Ensuring model accuracy |

---

## 📊 Diagrams

Visual reference for architecture and data model.

- [Data Model ERD](diagrams/datamodel.png) - Complete entity-relationship diagram
- [Cortex Search + RAG Architecture](diagrams/cortex-search-rag.png) - Intelligence layer architecture

---

## 📚 Medium Article Series

Deep-dive articles on Snowflake Intelligence best practices. **Start here to learn concepts**, then refer to Docs and SQL for details and implementation.

| Article | Focus | Read Time | Navigation |
|---------|-------|-----------|-----------|
| [Hub Article](../medium/claude/hub_article.md) | 3-layer framework overview (Intelligence/Foundation/Trust) | 18-20 min | Choose a layer below |
| [Subarticle 1: Intelligence Layer](../medium/claude/subarticle_1_intelligence_layer.md) | Context, semantic models, search, embeddings, RAG | 20-22 min | → [Docs](reference/embedding_strategy.md) → [SQL](../sql/search/) |
| [Subarticle 2: Foundation Layer](../medium/claude/subarticle_2_foundation_layer.md) | Medallion, schema design, optimization, automation | 20-22 min | → [Docs](implementation/data_model.md) → [SQL](../sql/analytics/) |
| [Subarticle 3: Trust Layer](../medium/claude/subarticle_3_trust_layer.md) | Governance, quality, evaluation, versioning | 20-22 min | → [Docs](governance/) → [SQL](../sql/setup/) |

**Navigation:** Each article links to relevant Docs. Each Doc links to Medium & SQL. Each SQL file has navigation comments.

---

## 🎯 Common Tasks

### Deploying the Project
```bash
# Full deployment (data download + Snowflake setup)
make demo

# Step-by-step deployment
make data      # Download source data
make setup     # Create Snowflake objects
make load      # Load data into Snowflake
make model     # Build curated model
make search    # Create search services
```

See: [Getting Started](implementation/getting-started.md)

---

### Adding New Metrics
1. Update `models/DMEPOS_SEMANTIC_MODEL.yaml`
2. Add metric definition to [Metric Catalog](reference/metric_catalog.md)
3. Follow [Publish Checklist](governance/semantic_publish_checklist.md)
4. Update [Semantic Model Changelog](governance/semantic_model_changelog.md)

---

### Testing AI Accuracy
1. Review [Human Validation Log](governance/human_validation_log.md) for golden questions
2. Build reference dashboards in Snowsight
3. Compare AI results to human results
4. Log discrepancies and iterate on semantic model

See: [Publish Checklist](governance/semantic_publish_checklist.md)

---

### Implementing RAG (Policy Q&A)
1. Download CMS PDFs from [PDF Sources](reference/pdf_sources.md)
2. Follow extraction and chunking workflow
3. Generate embeddings using [Embedding Strategy](reference/embedding_strategy.md)
4. Create PDF search service

---

## 🔍 By Use Case

**"I want to deploy the project"**
→ [Getting Started](implementation/getting-started.md)

**"I want to understand the data model"**
→ [Data Model](implementation/data_model.md) + [Diagrams](diagrams/)

**"I want to add new metrics"**
→ [Metric Catalog](reference/metric_catalog.md) + [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md)

**"I want to improve AI accuracy"**
→ [Human Validation Log](governance/human_validation_log.md) + [Publish Checklist](governance/semantic_publish_checklist.md)

**"I want to add policy-based Q&A"**
→ [Embedding Strategy](reference/embedding_strategy.md) + [PDF Sources](reference/pdf_sources.md)

**"I want to create a Cortex Agent"**
→ [Cortex Agent Creation](reference/cortex_agent_creation.md)

**"I want to understand routing logic"**
→ [Agent Guidance](reference/agent_guidance.md)

**"I want to implement PDF search"**
→ [Embedding Strategy](reference/embedding_strategy.md) + [PDF Sources](reference/pdf_sources.md)

**"I want to version and publish model changes"**
→ [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md) + [Semantic Model Changelog](governance/semantic_model_changelog.md)

---

## 📖 Recommended Reading Order

### For First-Time Users
1. [Getting Started](implementation/getting-started.md) - Deploy the project
2. [Data Model](implementation/data_model.md) - Understand the structure
3. [Snowflake Intelligence Setup](implementation/snowflake_intelligence_setup.md) - Configure UI
4. [Agent Guidance](reference/agent_guidance.md) - Learn routing rules

### For Data Engineers
1. [Getting Started](implementation/getting-started.md) - Deployment
2. [Data Model](implementation/data_model.md) - ERD and schema design
3. [Medium Subarticle 2: Foundation Layer](../medium/claude/subarticle_2_foundation_layer.md) - Architecture deep dive

### For Analytics Engineers
1. [Metric Catalog](reference/metric_catalog.md) - Available metrics
2. [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md) - Version management
3. [Medium Subarticle 1: Intelligence Layer](../medium/claude/subarticle_1_intelligence_layer.md) - Semantic models deep dive

### For ML/AI Engineers
1. [Embedding Strategy](reference/embedding_strategy.md) - RAG implementation & PDF chunking
2. [PDF Sources](reference/pdf_sources.md) - Document sources and upload
3. [Medium Subarticle 1: Intelligence Layer](../medium/claude/subarticle_1_intelligence_layer.md) - Embeddings & RAG

### For Agent Engineers
1. [Cortex Agent Creation](reference/cortex_agent_creation.md) - Building agents with SQL
2. [Agent Guidance](reference/agent_guidance.md) - Routing rules and best practices
3. [Embedding Strategy](reference/embedding_strategy.md) - Search services (tools for agents)

### For Data Stewards/Governance
1. [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md) - Lifecycle management
2. [Human Validation Log](governance/human_validation_log.md) - Validation framework
3. [Publish Checklist](governance/semantic_publish_checklist.md) - Quality gates
4. [Medium Subarticle 3: Trust Layer](../medium/claude/subarticle_3_trust_layer.md) - Governance deep dive

---

## 📝 What's Not Here

**Archived documents** (replaced by newer docs):
- [archive/architecture.md](archive/architecture.md) - Basic scaffold (see [Data Model](implementation/data_model.md) instead)
- [archive/data_dictionary.md](archive/data_dictionary.md) - Basic dictionary (see [Metric Catalog](reference/metric_catalog.md) instead)
- [archive/project_overview.md](archive/project_overview.md) - Old overview (see [Getting Started](implementation/getting-started.md) instead)

---

## 🆘 Getting Help

**Found an issue or have questions?**
- Check [Troubleshooting](implementation/getting-started.md#troubleshooting) in Getting Started
- Review [Common Issues](implementation/snowflake_intelligence_setup.md#troubleshooting) in SF Intelligence Setup
- See [Medium articles](../medium/claude/) for detailed explanations

**Contributing:**
- Follow [Semantic Model Lifecycle](governance/semantic_model_lifecycle.md) for model changes
- Use [Publish Checklist](governance/semantic_publish_checklist.md) before deploying
- Document changes in [Semantic Model Changelog](governance/semantic_model_changelog.md)

---

## 📂 Complete File List

See [FILE_GUIDE.md](FILE_GUIDE.md) for detailed descriptions of every document in this project.
