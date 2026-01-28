# Semantic Model Lifecycle

This document defines the lifecycle management process for the DMEPOS Semantic Model used with Snowflake Intelligence (Cortex Analyst).
---

## Navigation

| Want This | See This |
|-----------|----------|
| 📖 **Trust Layer Governance** | [Subarticle 3: The Trust Layer](../../medium/claude/subarticle_3_trust_layer.md) |
| 💾 **Semantic Model Tests** | [SQL: Semantic Tests](../../sql/intelligence/semantic_model_tests.sql) |
| 💾 **Evaluation Framework** | [SQL: Eval Seed](../../sql/intelligence/eval_seed.sql) |
| 📚 **Validation Log** | [Human Validation Log](human_validation_log.md) |

---


## Lifecycle Stages

```
Draft --> Review --> Published --> Deprecated
```

### 1. Draft
- Initial creation or major updates
- Internal testing only
- Not exposed to end users
- Validation against eval set required

### 2. Review
- Domain expert validation
- Accuracy checks against known answers
- Business logic verification
- Stakeholder sign-off pending

### 3. Published
- Production-ready, user-facing
- Monitored via query logs
- Feedback collection active
- Version tagged in changelog

### 4. Deprecated
- Marked for removal
- Migration guidance provided
- Successor version identified
- Grace period for transition

## Roles and Responsibilities

| Role | Responsibilities |
|------|------------------|
| **Model Author** | Creates and updates model, runs tests, documents changes |
| **Domain Reviewer** | Validates business logic, verifies metric definitions |
| **Data Steward** | Approves for production, ensures governance compliance |
| **Data Analyst** | Validates outputs against dashboards, provides feedback |

## Review Cadence

| Frequency | Activity |
|-----------|----------|
| **Weekly** | Review query logs for failures or unexpected patterns |
| **Monthly** | Accuracy metrics review, feedback triage |
| **Quarterly** | Major version updates, comprehensive validation |
| **Ad-hoc** | Critical bug fixes, urgent business changes |

> **💾 See SQL:** Query logs and test results in [semantic_model_tests.sql](../../sql/intelligence/semantic_model_tests.sql)

## Promotion Process

### Draft to Review
1. All semantic tests pass
2. Eval set queries return expected results
3. Documentation updated (changelog, metric catalog)
4. Model author creates review request

### Review to Published
1. Domain reviewer approves metric definitions
2. Data analyst validates against dashboard outputs
3. Data steward confirms governance compliance
4. Version number incremented
5. YAML uploaded to Snowflake stage

### Published to Deprecated
1. Successor version published
2. Migration guide created
3. Deprecation notice added to changelog
4. Grace period defined (typically 30 days)

## Version Numbering

Format: `MAJOR.MINOR.PATCH`

- **MAJOR**: Breaking changes (metric renamed, dimension removed)
- **MINOR**: New features (new metric, new filter)
- **PATCH**: Bug fixes, documentation updates

Current version: `1.0.0`

## Quality Gates

Before any version is published:


> **💾 Reference:** Run tests from [semantic_model_tests.sql](../../sql/intelligence/semantic_model_tests.sql)

- [ ] All semantic tests pass (see `models/semantic_model_tests.sql`)
- [ ] Verified queries return expected results
- [ ] No critical data quality issues
- [ ] Changelog updated
- [ ] Metric catalog current
- [ ] At least one domain reviewer approved

## Feedback Integration

1. Collect feedback via `ANALYTICS.SEMANTIC_FEEDBACK` table
2. Triage feedback weekly
3. High-impact issues prioritized for next release
4. Feedback status tracked: `open` -> `reviewed` -> `implemented` or `rejected`

## Related Documentation

- [Metric Catalog](metric_catalog.md) - Business definitions for all metrics
- [Semantic Model Changelog](semantic_model_changelog.md) - Version history
- [Publish Checklist](semantic_publish_checklist.md) - Pre-publish validation steps
- [Agent Guidance](agent_guidance.md) - Routing and validation guidance
- [Execution Guide](execution_guide.md) - Deployment instructions
