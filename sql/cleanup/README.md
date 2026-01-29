# Cleanup & Teardown

## Overview

The `teardown.sql` script provides a safe, complete cleanup of all Snowflake Intelligence Medicare POS deployment objects.

## What Gets Deleted

When you run the teardown script, it permanently removes:

### Database Objects
- ✅ Database: `MEDICARE_POS_DB` (and all schemas)
  - `RAW` - Raw data tables
  - `CURATED` - Cleaned, typed data
  - `ANALYTICS` - Business-ready views
  - `SEARCH` - Cortex Search services and related tables
  - `INTELLIGENCE` - Query logging, evaluation seeds, validation framework
  - `GOVERNANCE` - Metadata catalog, lineage, quality checks

### Compute Resources
- ✅ Warehouse: `MEDICARE_POS_WH`

### Access Control
- ✅ Roles:
  - `MEDICARE_POS_ADMIN`
  - `MEDICARE_POS_INTELLIGENCE`

### AI/ML Objects
- ✅ Cortex Agent: `DMEPOS_INTELLIGENCE_AGENT_SQL`
- ✅ Cortex Search Services:
  - `HCPCS_SEARCH_SVC`
  - `DEVICE_SEARCH_SVC`
  - `PROVIDER_SEARCH_SVC`
  - `PDF_SEARCH_SVC`

## What Does NOT Get Deleted

The teardown script is designed to be safe and preserve your local development files:

- ✅ Local data files (`.json`, `.csv` in `data/`)
- ✅ SQL scripts (everything in `sql/`)
- ✅ Semantic models (everything in `models/`)
- ✅ Documentation (everything in `docs/` and `medium/`)
- ✅ Code files (`.py`, `.sh`, `Makefile`)

## Usage

### Via Makefile (Recommended)

```bash
make teardown
```

This target includes a safety confirmation prompt:
```
⚠️  WARNING: This will DELETE everything!
    - Database: MEDICARE_POS_DB
    - Warehouse: MEDICARE_POS_WH
    - Roles: MEDICARE_POS_ADMIN, MEDICARE_POS_INTELLIGENCE
    - All tables, views, search services, agents

Type 'yes' to confirm deletion:
```

### Direct SQL Execution

If you need to run the script directly:

```bash
snow sql -c sf_int -f sql/cleanup/teardown.sql
```

Or in Snowsight:
1. Copy contents of `sql/cleanup/teardown.sql`
2. Paste into Snowsight editor
3. Run as `ACCOUNTADMIN` role

## After Teardown

Once teardown is complete, you can:

1. **Redeploy from scratch:**
   ```bash
   make demo          # Quick demo deployment
   make deploy-all    # Full production setup
   ```

2. **Reuse downloaded data:**
   - CMS/FDA data files remain in `data/`
   - They'll be reused on next `make load`
   - Delete `data/` files if you want fresh downloads

## Safety Features

The teardown script includes multiple safety measures:

1. **IF EXISTS clauses** - Script won't fail if objects don't exist
2. **Idempotent** - Safe to run multiple times
3. **Clear order of deletion** - Drops dependencies first (Agent → Search services → Schemas)
4. **Verification output** - Shows what was deleted
5. **Makefile confirmation** - Requires typing "yes" to proceed

## When to Use

Use `make teardown` when:
- ✅ You want to reset deployment and start fresh
- ✅ You've made changes and want a clean slate
- ✅ You want to test the full deployment end-to-end
- ✅ You're debugging deployment issues
- ✅ You're done testing and want to clean up

## Related Commands

| Command | Purpose |
|---------|---------|
| `make teardown` | Complete cleanup (database, warehouse, roles) |
| `make clean-tests` | Clear just test results (keep infrastructure) |
| `make demo` | Fresh deployment from scratch |
| `make rebuild-model` | Recreate data model (keep infrastructure) |
| `make rebuild-search` | Recreate search services (keep infrastructure) |

## Troubleshooting

### "Permission denied" Error
- Ensure you're running as `ACCOUNTADMIN` role
- Check your Snowflake CLI connection: `snow connection list`

### Script Hangs After Confirmation
- The script is executing in Snowflake
- Wait for completion (typically 10-30 seconds)
- Check Snowflake activity monitor if needed

### Want to Cancel Teardown?
- Hit `Ctrl+C` before entering "yes" at confirmation prompt
- Or simply don't type "yes" when prompted

## Questions?

See related documentation:
- [Getting Started Guide](../../docs/implementation/getting-started.md)
- [Makefile Documentation](../../Makefile)
- [Architecture Overview](../../medium/claude/subarticle_2_foundation_layer.md)
