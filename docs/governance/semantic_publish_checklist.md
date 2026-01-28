# Semantic Model Publish Checklist

Complete this checklist before publishing any version of the semantic model to production.

---

## Pre-Publish Validation

### Data Quality
- [ ] All data quality checks pass (`make quality`)
- [ ] Row counts within expected range (no sudden drops/spikes)
- [ ] No unexpected NULL values in key fields
- [ ] Key metrics return reasonable values

### Semantic Tests
- [ ] All regression tests pass (`models/semantic_model_tests.sql`)
- [ ] Verified queries return expected results
- [ ] Edge case queries handled gracefully

### Model Structure
- [ ] All metrics have documentation in metric catalog
- [ ] All dimensions have descriptions in YAML
- [ ] Filters tested with sample queries
- [ ] Relationships defined correctly

### Business Approval
- [ ] Domain expert reviewed metric definitions
- [ ] Sample Analyst queries produce correct results
- [ ] Edge cases documented (see metric catalog)
- [ ] Business stakeholder sign-off obtained

### Technical Validation
- [ ] YAML syntax validated (no parse errors)
- [ ] Model loads in Cortex Analyst without errors
- [ ] Eval set queries return expected patterns
- [ ] No breaking changes from previous version (or migration documented)

### Documentation
- [ ] Changelog updated with new version
- [ ] Version number incremented appropriately
- [ ] Metric catalog reflects any changes
- [ ] Lifecycle status updated

---

## Human Validation Gate

### Dashboard Comparison
- [ ] At least 3 dashboards built/updated
- [ ] Key insights documented
- [ ] Dashboard results match Analyst outputs

### Golden Questions
- [ ] 10 golden questions tested
- [ ] Expected answers documented
- [ ] Match score >= 80% for simple questions
- [ ] Match score >= 65% for moderate questions

### Validation Results Logged
- [ ] AI validation results recorded in `AI_VALIDATION_RESULTS`
- [ ] Improvement candidates identified
- [ ] Critical mismatches resolved

---

## Deployment Steps

### 1. Backup Current Version
```sql
-- Copy current model to backup location
-- Document rollback procedure
```

### 2. Upload New Model
```bash
# Upload YAML to Snowflake stage
snowsql -q "PUT file://models/DMEPOS_SEMANTIC_MODEL.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
```

### 3. Verify Deployment
```sql
-- Test query against new model
-- Confirm expected behavior
```

### 4. Update Instrumentation
```sql
-- Log deployment event
INSERT INTO ANALYTICS.AUDIT_LOG (event_type, object_name, action_details)
VALUES ('model_deployment', 'DMEPOS_SEMANTIC_MODEL',
        OBJECT_CONSTRUCT('version', '1.x.x', 'deployed_by', CURRENT_USER()));
```

---

## Rollback Procedure

If issues are discovered post-deployment:

1. Restore backup YAML from previous version
2. Log rollback in audit table
3. Notify stakeholders
4. Document issue in changelog

---

## Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Model Author | | | |
| Domain Reviewer | | | |
| Data Steward | | | |

---

## Post-Publish Monitoring

### First 24 Hours
- [ ] Monitor query logs for errors
- [ ] Check for user feedback
- [ ] Verify key metrics stable

### First Week
- [ ] Review usage patterns
- [ ] Triage any reported issues
- [ ] Update documentation if needed

---

## Version History

| Version | Published Date | Published By | Notes |
|---------|---------------|--------------|-------|
| 1.0.0 | TBD | | Initial release |
