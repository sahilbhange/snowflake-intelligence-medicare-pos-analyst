# Semantic Model Changelog

All notable changes to the DMEPOS Semantic Model are documented here.

Format: [Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH)

---

## [1.0.0] - 2024-01-XX (Initial Release)

### Status: Published

### Tables
- **DIM_PROVIDER**: Provider dimension with NPI, name, specialty, location
- **FACT_CLAIMS**: Claims fact table at provider + HCPCS grain

### Dimensions Added
- `PROVIDER_NPI`, `PROVIDER_NAME`, `PROVIDER_SPECIALTY_DESC`, `PROVIDER_STATE`, `PROVIDER_CITY`, `PROVIDER_ZIP`
- `HCPCS_CODE`, `HCPCS_DESCRIPTION`, `RBCS_ID`, `SUPPLIER_RENTAL_INDICATOR`

### Facts Added
- `TOTAL_SUPPLIER_CLAIMS`, `TOTAL_SUPPLIER_SERVICES`, `TOTAL_SUPPLIER_BENES`, `TOTAL_SUPPLIERS`
- `AVG_SUPPLIER_MEDICARE_PAYMENT`, `AVG_SUPPLIER_MEDICARE_ALLOWED`, `AVG_SUPPLIER_SUBMITTED_CHARGE`

### Metrics Added
- Volume: `TOTAL_CLAIMS_SUM`, `TOTAL_SERVICES_SUM`, `TOTAL_BENEFICIARIES_SUM`, `TOTAL_SUPPLIERS_SUM`
- Payment: `AVG_MEDICARE_PAYMENT`, `AVG_MEDICARE_ALLOWED`, `AVG_SUBMITTED_CHARGE`
- Derived: `PAYMENT_TO_ALLOWED_RATIO`, `CLAIMS_PER_SUPPLIER`, `SERVICES_PER_CLAIM`, `BENEFICIARIES_PER_CLAIM`

### Filters Added
- Geographic: `california_providers`, `texas_providers`, `top_states`
- HCPCS: `durable_medical_equipment`, `common_hcpcs`, `exclude_null_hcpcs`
- Behavioral: `rentals_only`, `high_volume_providers`

### Verified Queries (15 total)
- `top_hcpcs_by_claims` (onboarding)
- `payment_ratio_by_state` (onboarding)
- `california_high_volume_providers` (onboarding)
- `dme_codes_summary` (onboarding)
- Additional regression queries for provider, geographic, and HCPCS analyses

### Notes
- Initial release supporting Snowflake Intelligence demo
- Data at provider + HCPCS grain (not claim-level)
- Public data only; no patient identifiers

---

## [Unreleased]

### Planned for v1.1.0
- [ ] Add `ALLOWED_PER_BENEFICIARY` metric
- [ ] Add `year_filter` for multi-year analysis (when data available)
- [ ] Enhanced model instructions for common question patterns
- [ ] Additional verified queries for edge cases

### Known Limitations
- No temporal dimension (single snapshot)
- HCPCS-to-device mapping is a demo simplification
- Rental indicator at HCPCS level, not claim level

---

## Migration Guide

### From v0.x to v1.0
Not applicable (initial release)

### Future Deprecations
None planned

---

## Feedback Log

| Date | Issue | Resolution | Version |
|------|-------|------------|---------|
| TBD | Example: Metric X returns unexpected results for filter Y | Pending | 1.1.0 |

---

## Reviewers

| Version | Reviewer | Date | Status |
|---------|----------|------|--------|
| 1.0.0 | Sahil Bhange | 2024-01-XX | Approved |
