# Governance Feasibility (Demo-First)

This repo includes “production-ish” governance templates, but the Medium hands-on series works best with a **small, digestible trust layer**.

## What the demo needs (and nothing more)

For a demo, governance should answer two questions:

1. **Can I safely show/share this column?** → sensitivity policy
2. **Is the dataset “healthy” today?** → quick profiling (row counts + null rates)

Everything else (full data dictionary, long validation logs, lineage registries) is useful later, but it slows down a tutorial.

## Recommended demo workflow

Run these after `make model` (and before/after you show Cortex Analyst):

```bash
# Minimal metadata (small table + sensitivity policy view)
make metadata-demo

# Lightweight profiling (small insert set into GOVERNANCE.DATA_PROFILE_RESULTS)
make profile-demo

# Or as a single step
make governance-demo
```

**What you can screenshot / explain in 30 seconds:**

- `GOVERNANCE.SENSITIVITY_POLICY` (how to handle `public` vs `internal` vs `confidential`)
- `GOVERNANCE.DATA_PROFILE_RESULTS` (row counts + null rates as “trust signals”)

## What’s automated vs manual (in this repo)

### Automated (one-command repeatable)

- `make metadata-demo` / `make profile-demo` (demo)
- `make metadata` / `make profile` (full templates)

This is automation in the “repeatable scripts” sense.

### Still manual (left as an exercise / production add-on)

- **Scheduling** (Snowflake TASKs): profiling scripts mention “nightly”, but this repo does not create tasks.
- **Alerting** (Slack/email): no notification wiring.
- **Quality check runner**: `DATA_QUALITY_CHECKS.check_sql` exists in the full template, but there’s no stored procedure/task that executes each check and writes `DATA_QUALITY_RESULTS`.
- **Human sign-off**: lifecycle/checklists are documented, not enforced by CI/CD gates.

## What we kept vs trimmed for the Medium series

### Keep (demo core)

- `sql/governance/metadata_demo.sql` → small `COLUMN_METADATA` + `SENSITIVITY_POLICY`
- `sql/governance/profile_demo.sql` → small `DATA_PROFILE_RESULTS` run
- `docs/governance/semantic_model_lifecycle.md` → lifecycle narrative (short and useful)
- `docs/governance/semantic_publish_checklist.md` → now includes a “demo checklist” section

### Keep as “advanced templates” (optional reading)

- `sql/governance/metadata_and_quality.sql` (full scaffolding: lineage, checks, agent hints)
- `sql/governance/run_profiling.sql` (bigger profiling set)
- `docs/governance/data_dictionary.md` (large, standards-heavy reference)
- `docs/governance/human_validation_log.md` (detailed worksheet)

## Upgrade path (when you want more than the demo)

When the tutorial becomes a real internal project, switch from demo targets to full targets:

```bash
make metadata
make profile
```

That expands the governance surface area (lineage, quality checks table, agent hints, etc.) without changing downstream pipelines.

