# Snowflake Intelligence Medicare POS Analyst

A compact demo project that showcases Snowflake Intelligence with a real healthcare dataset. It includes:

- A curated data model for Medicare DMEPOS claims.
- A semantic model for Cortex Analyst.
- Cortex Search services for HCPCS codes, medical devices (GUDID), and providers.

## Prerequisites

- Snowflake account with Cortex Search and Snowflake Intelligence enabled.
- Snowsight access.
- SnowSQL or Snowflake CLI for running scripts.

## Quickstart

Optional: run everything with a single command after setting your Snow CLI connection:

```bash
# Example: export PRIVATE_KEY_PASSPHRASE="<your passphrase>"
make demo
```

The Makefile assumes you already edited the `PUT` paths in `sql/ingestion/load_raw_data.sql`.

1. Create roles, warehouse, database, and schema:

```sql
-- sql/setup/setup_user_and_roles.sql
```

Update `target_user` before running.

2. Download source data:

```bash
python data/dmepos_referring_provider_download.py --max-rows 1000000
bash data/data_download.sh
```

3. Upload raw files to Snowflake stages:

```sql
-- sql/ingestion/load_raw_data.sql
```

Replace the file paths in the `PUT` statements.

4. Build the curated tables and views:

```sql
-- sql/transform/build_curated_model.sql
```

5. Create Cortex Search services:

```sql
-- models/cortex_search_hcpcs.sql
-- models/cortex_search_devices.sql
-- models/cortex_search_providers.sql
```

6. Create instrumentation and seed eval prompts:

```sql
-- models/instrumentation.sql
-- models/eval_seed.sql
```

7. Create metadata and quality scaffolding (optional but recommended):

```sql
-- sql/governance/metadata_and_quality.sql
```

8. Upload the semantic model:

- File: `models/DMEPOS_SEMANTIC_MODEL.yaml`
- Target: `MEDICARE_POS_DB.ANALYTICS`

9. Add sources in Snowflake Intelligence:

- Follow `models/snowflake_intelligence_setup.md`.

## Demo prompts

- "Top 10 states by claim volume"
- "What is HCPCS code E1390?"
- "Find oxygen concentrators"
- "Find endocrinologists in California"

## Repository layout

- `sql/` - Setup, ingestion, transform, search, governance, and intelligence SQL.
- `models/` - Semantic model, Cortex Search SQL, and instrumentation.
- `data/` - Download helpers (raw data is gitignored).
- `docs/` - Diagrams and visuals for articles.
- `backup/` - Archived material (ignored by git).

## Docs scaffolds

- `docs/data_dictionary.md` - Data dictionary outline for the Medium article.
- `docs/architecture.md` - Architecture outline and story alignment.
- `docs/project_overview.md` - Datasets, model grain, and Analyst + Search flow.
- `docs/data_model.md` - Mermaid data model diagram.
- `docs/medium_article_draft.md` - Medium article outline and talking points.
- `refine_plan.md` - Agentic refinement plan and next steps.
