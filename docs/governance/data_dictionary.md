# Data Dictionary

Comprehensive data dictionary following DAMA-DMBOK and ISO 8000 standards for data governance, quality, and lineage.

---

## Overview

This data dictionary serves as the authoritative source for:
- **Technical Metadata:** Schema, data types, constraints
- **Business Metadata:** Definitions, business rules, ownership
- **Governance Metadata:** Classification, compliance, access controls
- **Quality Metadata:** Validation rules, quality checks, profiling results
- **Lineage Metadata:** Data sources, transformations, dependencies

**Standards Compliance:**
- DAMA-DMBOK 2.0 (Data Management Body of Knowledge)
- ISO 8000-2 (Data Quality)
- GDPR (General Data Protection Regulation)
- HIPAA (Health Insurance Portability and Accountability Act)
- CMS Data Standards

---

## Governance Framework

### Data Classification Levels

| Level | Definition | Examples | Access Requirements |
|-------|------------|----------|---------------------|
| **Public** | Publicly available data from government sources | CMS public datasets, FDA device catalog | No restrictions |
| **Internal** | Internal use only, no PII | Aggregated metrics, dashboards | Authenticated users |
| **Confidential** | Sensitive business data | Provider NPI with details | Role-based access |
| **Restricted** | Regulated data requiring compliance | PHI, patient identifiers (not in this dataset) | Strict access controls + audit |

### Compliance Tags

- **GDPR:** Data subject to GDPR if EU citizens included
- **HIPAA:** Protected Health Information (PHI) - provider identifiers require safeguards
- **CMS Public Use:** CMS public use file requirements
- **FDA Compliance:** Device data subject to FDA regulations

---

## Data Sources

### Source Systems

| Source ID | Source Name | Provider | Update Frequency | Grain |
|-----------|-------------|----------|------------------|-------|
| CMS-DMEPOS-001 | CMS DMEPOS Referring Provider | Centers for Medicare & Medicaid Services | Annual | Provider + HCPCS (single-year snapshot) |
| FDA-GUDID-001 | FDA Global Unique Device Identification Database | U.S. Food and Drug Administration | Monthly | Device Identifier (DI) |

### Data Acquisition

**CMS DMEPOS:**
- **Method:** API download (JSON)
- **URL:** https://data.cms.gov/data-api/v1/dataset/86b4807a-d63a-44be-bfdf-ffd398d5e623/data
- **License:** Public domain
- **Attribution:** CMS Public Use Files

**FDA GUDID:**
- **Method:** Bulk download (ZIP with delimited files)
- **URL:** https://accessgudid.nlm.nih.gov/download
- **License:** Public domain
- **Attribution:** FDA OpenFDA

---

## Schema Architecture

### Medallion Layers

| Layer | Schema | Purpose | Data Classification | Retention |
|-------|--------|---------|---------------------|-----------|
| **Bronze** | RAW | Raw landing zone, minimal transformation | Public | 90 days |
| **Silver** | CURATED | Cleaned, typed, deduplicated | Public | 2 years |
| **Gold** | ANALYTICS | Business-ready dimensions and facts | Internal | 5 years |
| **Search** | SEARCH | Search corpora for Cortex Search | Internal | 2 years |
| **Intelligence** | INTELLIGENCE | AI instrumentation, eval sets, logs | Internal | 1 year |
| **Governance** | GOVERNANCE | Metadata, lineage, quality checks | Internal | 7 years |

**Implementation note (project alignment):**
- Objects are created by SQL scripts under `sql/`; retention/archival are not enforced automatically.
- `ANALYTICS.*` are views built from `CURATED.*` (see `sql/transform/build_curated_model.sql`).

---

## Data Dictionary: RAW Layer

### RAW.RAW_DMEPOS

**Purpose:** Raw landing for CMS DMEPOS JSON (one VARIANT per record)
**Classification:** Public
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Description |
|--------|-----------|----------|----------------|-------------|
| v | VARIANT | No | Public | One CMS API JSON record (loaded from staged JSON array) |

**Quality Rules:**
- Must be valid JSON
- Each row should contain CMS fields used downstream (e.g., `Rfrg_NPI`, `HCPCS_CD`)

**Lineage:**
- **Source:** CMS DMEPOS API
- **Transformation:** None (raw ingestion via `sql/ingestion/load_raw_data.sql`)
- **Downstream:** CURATED.DMEPOS_CLAIMS (built by `sql/transform/build_curated_model.sql`)

---

### RAW.RAW_GUDID_DEVICE

**Purpose:** Raw landing for FDA GUDID device catalog
**Classification:** Public
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Description |
|--------|-----------|----------|----------------|-------------|
| primary_di | STRING | Yes | Public | Primary device identifier (DI) from GUDID |
| public_device_record_key | STRING | Yes | Public | Public record key for the device |
| public_version_status | STRING | Yes | Public | Version status (published/updated) |
| device_record_status | STRING | Yes | Public | Device record status from the raw file |
| public_version_number | NUMBER | Yes | Public | Public version number |
| device_publish_date | STRING | Yes | Public | Publish date (raw string; cast in curated layer) |
| device_comm_distribution_status | STRING | Yes | Public | Commercial distribution status (raw string) |
| brand_name | STRING | Yes | Public | Brand name |
| version_model_number | STRING | Yes | Public | Version/model number |
| catalog_number | STRING | Yes | Public | Catalog number |
| company_name | STRING | Yes | Public | Manufacturer/labeler name |
| device_description | STRING | Yes | Public | Device description text |
| rx | STRING | Yes | Public | Rx flag from raw file |
| otc | STRING | Yes | Public | OTC flag from raw file |

**Quality Rules:**
- primary_di should be present for records used downstream
- device_publish_date should be parseable as a date for curated records

**Lineage:**
- **Source:** FDA GUDID Bulk Download
- **Transformation:** None (raw ingestion via `sql/ingestion/load_raw_data.sql`)
- **Downstream:** CURATED.GUDID_DEVICES (built by `sql/transform/build_curated_model.sql`)

**Related RAW tables (GUDID):**
- This project ingests additional `RAW.RAW_GUDID_*` tables (e.g., identifiers, contacts, product codes) defined in `sql/ingestion/load_raw_data.sql`.

---

## Data Dictionary: CURATED Layer

### CURATED.DMEPOS_CLAIMS

**Purpose:** Cleaned and typed claims at provider + HCPCS grain
**Classification:** Public (aggregated, no PHI)
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward
**Grain:** One row per referring provider + HCPCS code (annual aggregate)

| Column | Data Type | Nullable | Classification | Business Definition | Valid Values | Sample Values |
|--------|-----------|----------|----------------|---------------------|--------------|---------------|
| referring_npi | NUMBER | No | Internal | National Provider Identifier for referring physician | 10-digit NPI | 1003000126 |
| provider_last_name | STRING | Yes | Internal | Referring provider last name or org name | Free text | SMITH, JONES |
| provider_first_name | STRING | Yes | Internal | Referring provider first name | Free text | JOHN, MARY |
| provider_city | STRING | Yes | Internal | Referring provider city | Free text | LOS ANGELES |
| provider_state | STRING | Yes | Public | Referring provider state | US state abbreviations | CA, TX, NY |
| provider_zip | STRING | Yes | Internal | Referring provider 5-digit ZIP | 5-digit ZIP | 90001 |
| provider_country | STRING | Yes | Public | Country code (typically US) | Country codes | US |
| provider_specialty_code | STRING | Yes | Internal | CMS specialty code | CMS specialty codes | 11, 50 |
| provider_specialty_desc | STRING | Yes | Internal | CMS specialty description | Free text | Internal Medicine |
| provider_specialty_source | STRING | Yes | Internal | Source for specialty classification | CMS | CMS |
| rbcs_level | STRING | Yes | Public | RBCS level | Free text | Level 1 |
| rbcs_id | STRING | Yes | Public | Restructured BETOS Classification System (RBCS) identifier | Alphanumeric | DC002N |
| rbcs_desc | STRING | Yes | Public | RBCS description | Free text | DME: Oxygen and respiratory |
| hcpcs_code | STRING | No | Public | Healthcare Common Procedure Coding System code | 5-character alphanumeric | E1390, A4253 |
| hcpcs_description | STRING | Yes | Public | Description of HCPCS code | Free text | Oxygen concentrator |
| supplier_rental_indicator | STRING | Yes | Public | Rental equipment flag (at HCPCS level) | Y (Yes), N (No), null | Y, N |
| total_suppliers | NUMBER | Yes | Internal | Count of unique suppliers | >= 0 | 5, 12 |
| total_supplier_benes | NUMBER | Yes | Internal | Count of unique beneficiaries served (aggregated) | >= 0, may be suppressed | 45, 120 |
| total_supplier_claims | NUMBER | Yes | Public | Total count of claims | >= 0 | 100, 500 |
| total_supplier_services | NUMBER | Yes | Public | Total count of services rendered | >= total_supplier_claims | 150, 600 |
| avg_supplier_submitted_charge | NUMBER(38,4) | Yes | Public | Average supplier submitted charge (USD) | >= 0 | 125.50 |
| avg_supplier_medicare_allowed | NUMBER(38,4) | Yes | Public | Average Medicare allowed amount (USD) | >= 0 | 85.25 |
| avg_supplier_medicare_payment | NUMBER(38,4) | Yes | Public | Average Medicare payment amount (USD) | >= 0 | 68.20 |
| avg_supplier_medicare_standard | NUMBER(38,4) | Yes | Public | Average Medicare standardized amount (USD) | >= 0 | 70.00 |

**Business Rules:**
1. **Grain:** One row per (referring_npi, hcpcs_code) combination in the source snapshot
2. **Deduplication:** Not applied in the current build; the source is expected to be unique at the stated grain
3. **Suppression:** CMS may suppress beneficiary counts (< 11) for privacy
4. **Payment hierarchy:** avg_submitted_charge >= avg_allowed >= avg_payment (expected)
5. **Services >= Claims:** total_supplier_services >= total_supplier_claims (expected)
6. **NPI validation:** 10-digit numeric NPI (expected)

**Data Quality Checks:**
- No nulls in referring_npi, hcpcs_code
- avg_payment <= avg_allowed <= avg_submitted_charge
- total_supplier_services >= total_supplier_claims
- provider_state in valid US state list

**Lineage:**
- **Source:** RAW.RAW_DMEPOS
- **Transformation:** JSON parsing, type casting
- **SQL:** sql/transform/build_curated_model.sql
- **Downstream:** ANALYTICS.DIM_PROVIDER, ANALYTICS.FACT_DMEPOS_CLAIMS

**Compliance Notes:**
- NPIs are treated as internal in this project (provider identifier; not patient PHI)
- Beneficiary counts suppressed per CMS Data Use Agreement
- Public dataset, no direct PHI

---

### CURATED.GUDID_DEVICES

**Purpose:** Cleaned device catalog from FDA GUDID
**Classification:** Public
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward
**Grain:** One row per device identifier (DI)

| Column | Data Type | Nullable | Classification | Business Definition | Valid Values |
|--------|-----------|----------|----------------|---------------------|--------------|
| public_device_record_key | STRING | Yes | Public | Public record key (used as doc_id in search) | Free text |
| public_version_status | STRING | Yes | Public | Public version status | Free text |
| public_version_number | NUMBER | Yes | Public | Public version number | Integer |
| di_number | STRING | Yes | Public | Primary Device Identifier (DI) | Free text |
| device_name | STRING | Yes | Public | Device name (brand_name in this build) | Free text |
| brand_name | STRING | Yes | Public | Brand or trade name | Free text |
| version_or_model_number | STRING | Yes | Public | Version/model number | Free text |
| catalog_number | STRING | Yes | Public | Catalog number | Free text |
| company_name | STRING | Yes | Public | Manufacturer/labeler | Free text |
| device_description | STRING | Yes | Public | Device description | Free text |
| device_status | STRING | Yes | Public | Device record status | Free text |
| device_publish_date | DATE | Yes | Public | Device publish date | Valid date |
| commercial_distribution_status | STRING | Yes | Public | Commercial distribution status | Free text |

**Business Rules:**
1. **Grain:** One row per device record as loaded (no additional dedup in current build)
2. **Identifier:** `di_number` comes from `RAW.RAW_GUDID_DEVICE.primary_di`
3. **Active devices:** Not filtered in CURATED; downstream search/docs may filter on distribution status

**Data Quality Checks:**
- di_number should be unique for curated records used downstream
- device_publish_date should be valid where present
- company_name should not be null for records used in device search/docs

**Lineage:**
- **Source:** RAW.RAW_GUDID_DEVICE
- **Transformation:** JSON/CSV parsing, type casting
- **SQL:** sql/transform/build_curated_model.sql
- **Downstream:** ANALYTICS.DIM_DEVICE

**Compliance Notes:**
- Public data per FDA OpenFDA
- Subject to FDA device registration requirements

---

## Data Dictionary: ANALYTICS Layer

### ANALYTICS.DIM_PROVIDER

**Purpose:** Provider dimension for analytics
**Type:** View (dimension)
**Classification:** Confidential
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Business Definition | Synonyms |
|--------|-----------|----------|----------------|---------------------|----------|
| referring_npi | NUMBER | No | Internal | National Provider Identifier (primary key) | NPI, provider_id |
| provider_last_name | STRING | Yes | Confidential | Provider last name / org name | surname |
| provider_first_name | STRING | Yes | Confidential | Provider first name | given name |
| provider_specialty_code | STRING | Yes | Internal | Provider specialty code | specialty code |
| provider_specialty_desc | STRING | Yes | Internal | Provider specialty description | specialty |
| provider_specialty_source | STRING | Yes | Internal | Provider specialty source | source |
| provider_city | STRING | Yes | Internal | Provider city | city |
| provider_state | STRING | Yes | Public | Provider state | state, location |
| provider_zip | STRING | Yes | Internal | Provider ZIP code | zip, postal_code |
| provider_country | STRING | Yes | Public | Provider country | country |

**Business Rules:**
- Implemented as a view over `CURATED.DMEPOS_CLAIMS` (`SELECT DISTINCT ...`)
- Filters out rows where `referring_npi` is null
- Provider full name is derived in the semantic model (not stored as a column)

**Quality Rules:**
- No duplicate NPIs
- All NPIs in CURATED.DMEPOS_CLAIMS must exist

**Lineage:**
- **Source:** CURATED.DMEPOS_CLAIMS
- **Transformation:** SELECT DISTINCT, null filtering
- **SQL:** sql/transform/build_curated_model.sql

---

### ANALYTICS.DIM_DEVICE

**Purpose:** Device dimension for analytics
**Type:** View (dimension)
**Classification:** Public
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Business Definition | Synonyms |
|--------|-----------|----------|----------------|---------------------|----------|
| di_number | STRING | No | Public | Device Identifier (primary key) | DI, device_id |
| brand_name | STRING | Yes | Public | Device brand | brand, manufacturer_name |
| device_description | STRING | Yes | Public | Device description | description, device_name |
| company_name | STRING | Yes | Public | Manufacturer | manufacturer, company |
| version_or_model_number | STRING | Yes | Public | Device model/version | model |
| catalog_number | STRING | Yes | Public | Catalog number | catalog |
| device_status | STRING | Yes | Public | Device status | status |
| device_publish_date | DATE | Yes | Public | Publish date | publish date |
| commercial_distribution_status | STRING | Yes | Public | Distribution status | distribution |

**Business Rules:**
- Implemented as a view over `CURATED.GUDID_DEVICES` (`SELECT DISTINCT ...`)
- Not filtered to "active" devices in the view; downstream search/docs may filter

**Quality Rules:**
- di_number should be unique where present
- company_name should be present for records used in search/docs

**Lineage:**
- **Source:** CURATED.GUDID_DEVICES
- **Transformation:** SELECT DISTINCT
- **SQL:** sql/transform/build_curated_model.sql

---

### ANALYTICS.DIM_PRODUCT_CODE

**Purpose:** Product code dimension (FDA GUDID product codes)
**Type:** View
**Classification:** Public
**Owner:** Analytics Engineering Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| primary_di | STRING | Yes | Primary device identifier (DI) |
| product_code | STRING | Yes | FDA product code |
| product_code_name | STRING | Yes | FDA product code name |

**Lineage:**
- **Source:** RAW.RAW_GUDID_PRODUCT_CODES
- **Transformation:** SELECT DISTINCT, null filtering on product_code
- **SQL:** sql/transform/build_curated_model.sql

---

### ANALYTICS.FACT_DMEPOS_CLAIMS

**Purpose:** Analytics-ready fact table for claims analysis
**Type:** View (aggregate fact)
**Classification:** Public (aggregated)
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward
**Grain:** One row per provider + HCPCS code

| Column | Data Type | Nullable | Classification | Business Definition | Aggregation Type |
|--------|-----------|----------|----------------|---------------------|------------------|
| referring_npi | NUMBER | Yes | Internal | Referring provider NPI | Dimension |
| provider_last_name | STRING | Yes | Confidential | Provider last name / org name | Dimension |
| provider_first_name | STRING | Yes | Confidential | Provider first name | Dimension |
| provider_city | STRING | Yes | Internal | Provider city | Dimension |
| provider_state | STRING | Yes | Public | Provider state | Dimension |
| provider_zip | STRING | Yes | Internal | Provider ZIP | Dimension |
| provider_country | STRING | Yes | Public | Provider country | Dimension |
| provider_specialty_code | STRING | Yes | Internal | Provider specialty code | Dimension |
| provider_specialty_desc | STRING | Yes | Internal | Provider specialty description | Dimension |
| provider_specialty_source | STRING | Yes | Internal | Provider specialty source | Dimension |
| rbcs_level | STRING | Yes | Public | RBCS level | Dimension |
| rbcs_id | STRING | Yes | Public | RBCS ID | Dimension |
| rbcs_desc | STRING | Yes | Public | RBCS description | Dimension |
| hcpcs_code | STRING | Yes | Public | HCPCS code | Dimension |
| hcpcs_description | STRING | Yes | Public | HCPCS description | Dimension |
| supplier_rental_indicator | STRING | Yes | Public | Rental flag (Y/N) | Dimension |
| total_suppliers | NUMBER | Yes | Public | Total suppliers | SUM |
| total_supplier_benes | NUMBER | Yes | Internal | Total beneficiaries (suppressed if < 11) | SUM |
| total_supplier_claims | NUMBER | Yes | Public | Total claims | SUM |
| total_supplier_services | NUMBER | Yes | Public | Total services | SUM |
| avg_supplier_submitted_charge | NUMBER(38,4) | Yes | Public | Average submitted charge | AVG |
| avg_supplier_medicare_allowed | NUMBER(38,4) | Yes | Public | Average Medicare allowed | AVG |
| avg_supplier_medicare_payment | NUMBER(38,4) | Yes | Public | Average Medicare payment | AVG |
| avg_supplier_medicare_standard | NUMBER(38,4) | Yes | Public | Average Medicare standardized | AVG |
| provider_specialty_desc_ref | STRING | Yes | Internal | Specialty description from DIM_PROVIDER join | Dimension |
| device_brand_name | STRING | Yes | Public | Brand name from DIM_DEVICE join (demo) | Dimension |

**Business Rules:**
- Implemented as a view over `CURATED.DMEPOS_CLAIMS` with enrichment joins
- Joins `ANALYTICS.DIM_PROVIDER` on `referring_npi`
- Joins `ANALYTICS.DIM_DEVICE` on `hcpcs_code = di_number` (demo simplification; may produce sparse matches)

**Quality Rules:**
- Referential integrity: referring_npi exists in DIM_PROVIDER
- avg_supplier_medicare_payment <= avg_supplier_medicare_allowed
- total_supplier_services >= total_supplier_claims

**Lineage:**
- **Source:** CURATED.DMEPOS_CLAIMS, ANALYTICS.DIM_PROVIDER, ANALYTICS.DIM_DEVICE
- **Transformation:** Enrichment joins, denormalization
- **SQL:** sql/transform/build_curated_model.sql
- **Downstream:** Semantic model, Snowflake Intelligence

---

## Data Dictionary: SEARCH Layer

### SEARCH.HCPCS_SEARCH_DOCS

**Purpose:** HCPCS code search corpus for Cortex Search
**Classification:** Public
**Owner:** AI/ML Engineering Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| doc_id | STRING | No | Search document identifier (HCPCS code) |
| doc_type | STRING | No | Document type (fixed: `hcpcs_definition`) |
| title | STRING | Yes | Short title used in search results |
| body | STRING | Yes | Searchable text used by Cortex Search |
| hcpcs_code | STRING | Yes | HCPCS code |
| hcpcs_description | STRING | Yes | HCPCS description |
| rbcs_id | STRING | Yes | RBCS ID |
| supplier_rental_indicator | STRING | Yes | Rental flag (Y/N) |

**Lineage:**
- **Source:** ANALYTICS.FACT_DMEPOS_CLAIMS
- **Transformation:** DISTINCT + formatted body/title for search
- **Downstream:** SEARCH.HCPCS_SEARCH_SVC

---

### SEARCH.DEVICE_SEARCH_DOCS

**Purpose:** Device search corpus for Cortex Search
**Classification:** Public
**Owner:** AI/ML Engineering Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| doc_id | STRING | No | Search document identifier (public_device_record_key) |
| doc_type | STRING | No | Document type (fixed: `medical_device`) |
| title | STRING | Yes | Short title used in search results |
| body | STRING | Yes | Searchable text used by Cortex Search |
| di_number | STRING | Yes | Device identifier (DI) |
| brand_name | STRING | Yes | Brand name |
| company_name | STRING | Yes | Manufacturer |
| version_or_model_number | STRING | Yes | Model/version |
| catalog_number | STRING | Yes | Catalog number |
| device_description | STRING | Yes | Device description |

**Lineage:**
- **Source:** CURATED.GUDID_DEVICES
- **Transformation:** Filtering + formatted body/title for search
- **Downstream:** SEARCH.DEVICE_SEARCH_SVC

---

### SEARCH.PROVIDER_SEARCH_DOCS

**Purpose:** Provider directory search corpus for Cortex Search
**Classification:** Internal
**Owner:** AI/ML Engineering Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| doc_id | STRING | No | Search document identifier (referring_npi) |
| doc_type | STRING | No | Document type (fixed: `provider_profile`) |
| title | STRING | Yes | Short title used in search results |
| body | STRING | Yes | Searchable text used by Cortex Search |
| referring_npi | NUMBER | Yes | Referring provider NPI |
| provider_first_name | STRING | Yes | Provider first name |
| provider_last_name | STRING | Yes | Provider last name |
| provider_specialty_code | STRING | Yes | Specialty code |
| provider_specialty_desc | STRING | Yes | Specialty description |
| provider_city | STRING | Yes | City |
| provider_state | STRING | Yes | State |
| provider_zip | STRING | Yes | ZIP |
| provider_country | STRING | Yes | Country |

**Lineage:**
- **Source:** ANALYTICS.DIM_PROVIDER
- **Transformation:** Formatted body/title for search
- **Downstream:** SEARCH.PROVIDER_SEARCH_SVC

---

## Data Dictionary: INTELLIGENCE Layer

### INTELLIGENCE.ANALYST_EVAL_SET

**Purpose:** Evaluation questions for semantic model testing
**Classification:** Internal
**Owner:** AI/ML Engineering Team
**Steward:** Data Quality Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| eval_id | STRING | No | Unique eval prompt identifier |
| category | STRING | Yes | Category grouping (provider/hcpcs/geo/etc.) |
| question | STRING | No | Natural language question |
| expected_pattern | STRING | Yes | Expected SQL pattern fragment for validation |
| notes | STRING | Yes | Optional reviewer notes |
| created_at | TIMESTAMP_NTZ | No | Creation timestamp |

**Quality Rules:**
- question must be valid natural language
- category should be a short, consistent label (e.g., `provider`, `hcpcs`, `geo`)

---

### INTELLIGENCE.ANALYST_QUERY_LOG

**Purpose:** Query logging for Cortex Analyst usage
**Classification:** Internal
**Owner:** AI/ML Engineering Team
**Retention:** 1 year

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| query_id | STRING | No | Unique query identifier |
| user_id | STRING | Yes | User who executed query |
| question | STRING | Yes | User's natural language question |
| generated_sql | STRING | Yes | AI-generated SQL |
| response_tokens | NUMBER | Yes | Token count (if captured by client/app) |
| latency_ms | NUMBER | Yes | End-to-end latency (if captured by client/app) |
| success_flag | BOOLEAN | Yes | Query success flag |
| created_at | TIMESTAMP_NTZ | No | Execution timestamp |

**Compliance:**
- PII scrubbed from logs
- 1-year retention per data governance policy

---

### INTELLIGENCE.ANALYST_RESPONSE_LOG

**Purpose:** Stores summarized answers and fallback notes (optional)
**Classification:** Internal
**Owner:** AI/ML Engineering Team
**Retention:** 1 year

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| query_id | STRING | No | Foreign key to `ANALYST_QUERY_LOG.query_id` |
| answer_summary | STRING | Yes | Short answer summary text |
| fallback_used | BOOLEAN | Yes | Whether a fallback path was used |
| notes | STRING | Yes | Optional debugging notes |
| created_at | TIMESTAMP_NTZ | No | Creation timestamp |

---

## Data Dictionary: GOVERNANCE Layer

### GOVERNANCE.DATASET_METADATA

**Purpose:** Dataset-level metadata (grain, refresh, ownership)
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| dataset_name | STRING | Yes | Dataset identifier |
| description | STRING | Yes | Dataset description |
| grain | STRING | Yes | Declared grain (free text) |
| source_system | STRING | Yes | Source system name |
| refresh_frequency | STRING | Yes | Refresh frequency (ad hoc/monthly/etc.) |
| freshness_sla_hours | NUMBER | Yes | Freshness SLA in hours |
| owner | STRING | Yes | Owning team/person |
| quality_score | NUMBER(5,2) | Yes | Optional quality score |
| governance_notes | STRING | Yes | Notes and handling guidance |
| created_at | TIMESTAMP_NTZ | No | Creation timestamp |
| updated_at | TIMESTAMP_NTZ | No | Last update timestamp |

### GOVERNANCE.COLUMN_METADATA

**Purpose:** Column-level metadata catalog
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| dataset_name | STRING | No | Dataset identifier (e.g., `DMEPOS_CLAIMS`) |
| column_name | STRING | No | Column name |
| data_type | STRING | Yes | Snowflake data type (as a string) |
| business_definition | STRING | Yes | Business definition |
| allowed_values | STRING | Yes | Allowed values/patterns |
| sensitivity | STRING | Yes | `public`, `internal`, `confidential`, `restricted` |
| example_value | STRING | Yes | Example value |
| created_at | TIMESTAMP_NTZ | No | Record creation timestamp |
| updated_at | TIMESTAMP_NTZ | No | Last update timestamp |

**Population:**
- Seeded by `sql/governance/metadata_and_quality.sql` (example entries)
- Intended for iterative improvement as the semantic model evolves

---

### GOVERNANCE.SENSITIVITY_POLICY

**Purpose:** Convenience view mapping column sensitivity to handling instructions
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| table_name | STRING | Yes | Dataset/table name |
| column_name | STRING | Yes | Column name |
| sensitivity_level | STRING | Yes | Sensitivity level |
| handling_instructions | STRING | Yes | Handling instructions derived from sensitivity |
| business_definition | STRING | Yes | Business definition |

---

### GOVERNANCE.DATA_LINEAGE

**Purpose:** Data lineage tracking
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| dataset_name | STRING | No | Dataset identifier |
| upstream_source | STRING | Yes | Upstream source reference (free text) |
| transformation_script | STRING | Yes | SQL/script path (free text) |
| notes | STRING | Yes | Notes about transformations or assumptions |
| created_at | TIMESTAMP_NTZ | No | Record creation timestamp |

**Use Cases:**
- Impact analysis for schema changes
- Data provenance for compliance
- Debugging data quality issues

---

### GOVERNANCE.DATA_QUALITY_CHECKS

**Purpose:** Data quality rules and results
**Classification:** Internal
**Owner:** Data Quality Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| check_id | STRING | No | Unique check identifier |
| table_name | STRING | No | Target table name (e.g., `CURATED.DMEPOS_CLAIMS`) |
| check_name | STRING | Yes | Short check name |
| check_description | STRING | Yes | Longer description |
| check_sql | STRING | No | SQL for the check |
| severity | STRING | Yes | Severity level (free text) |
| owner | STRING | Yes | Owning team/person (free text) |
| created_at | TIMESTAMP_NTZ | No | Creation timestamp |

**Quality Check Types:**
1. **Row Count:** Minimum expected rows
2. **Null Check:** Critical columns must not be null
3. **Uniqueness:** Primary keys must be unique
4. **Referential Integrity:** Foreign keys must exist
5. **Range Check:** Values within expected ranges
6. **Pattern Match:** Values match expected patterns (e.g., NPI format)

---

### GOVERNANCE.DATA_QUALITY_RESULTS

**Purpose:** Stores execution results for data quality checks
**Classification:** Internal
**Owner:** Data Quality Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| check_id | STRING | No | Foreign key to `DATA_QUALITY_CHECKS.check_id` |
| run_id | STRING | Yes | Run identifier (batch/job id) |
| run_ts | TIMESTAMP_NTZ | No | Run timestamp |
| status | STRING | Yes | pass/fail (or custom) |
| metric_value | NUMBER | Yes | Numeric metric value returned by the check |
| expected_threshold | STRING | Yes | Threshold definition (free text) |
| notes | STRING | Yes | Optional notes |

---

### GOVERNANCE.AGENT_HINTS

**Purpose:** Optional hints for analysts/agents (filters, joins, query patterns)
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| hint_id | STRING | No | Unique hint id (UUID) |
| hint_category | STRING | Yes | Category (geographic/hcpcs/payment/etc.) |
| hint_name | STRING | Yes | Short hint name |
| hint_description | STRING | Yes | Human-readable description |
| hint_sql_fragment | STRING | Yes | SQL fragment to apply |
| use_when | STRING | Yes | When to use the hint |
| priority | NUMBER | Yes | Priority (1 = highest) |
| created_at | TIMESTAMP_NTZ | No | Creation timestamp |

---

## Data Glossary

### Business Terms

| Term | Definition | Synonyms | Example |
|------|------------|----------|---------|
| **NPI** | National Provider Identifier - unique 10-digit identifier for healthcare providers | Provider ID, Provider Number | 1003000126 |
| **HCPCS** | Healthcare Common Procedure Coding System - standardized codes for medical procedures and supplies | Procedure Code, Service Code | E1390 |
| **DME** | Durable Medical Equipment - reusable medical equipment | Medical Device, Equipment | Wheelchair, oxygen concentrator |
| **POS** | Place of Service - location where healthcare services are provided | Service Location | Office, Home, Hospital |
| **DI** | Device Identifier - unique identifier for medical devices in FDA GUDID | Device ID | 00627595000712 |
| **GUDID** | Global Unique Device Identification Database - FDA database of medical devices | Device Database | N/A |
| **Beneficiary** | Medicare enrollee receiving services | Patient, Member | N/A (aggregated only) |
| **Allowed Amount** | Maximum amount Medicare approves for payment | Approved Amount | $85.25 |
| **Payment Amount** | Actual amount Medicare pays (after deductibles/coinsurance) | Reimbursement | $68.20 |

---

## Data Quality Standards

### Completeness Rules

| Layer | Table | Critical Columns | Completeness Target |
|-------|-------|------------------|---------------------|
| CURATED | DMEPOS_CLAIMS | referring_npi, hcpcs_code | 100% |
| CURATED | GUDID_DEVICES | di_number, company_name | 100% |
| ANALYTICS | FACT_DMEPOS_CLAIMS | referring_npi, hcpcs_code | 100% |

### Accuracy Rules

1. **Payment hierarchy:** avg_supplier_medicare_payment <= avg_supplier_medicare_allowed <= avg_supplier_submitted_charge
2. **Service/claim relationship:** total_supplier_services >= total_supplier_claims
3. **NPI validation:** 10-digit numeric, valid per NPPES
4. **State validation:** Must be valid US state abbreviation
5. **Date validation:** All dates must be <= current date

### Consistency Rules

1. **Referential integrity:** All NPIs in FACT_DMEPOS_CLAIMS exist in DIM_PROVIDER
2. **Deduplication:** No duplicate (referring_npi, hcpcs_code) combinations
3. **Naming conventions:** Snake_case for all column names

### Timeliness Rules

| Data Source | Update Frequency | SLA |
|-------------|------------------|-----|
| CMS DMEPOS | Annual | Loaded within 7 days of CMS publication |
| FDA GUDID | Monthly | Loaded within 3 days of FDA release |

---

## Data Retention Policy

| Schema | Retention Period | Archival Strategy | Compliance Requirement |
|--------|------------------|-------------------|------------------------|
| RAW | 90 days | Delete after promotion to CURATED | Operational efficiency |
| CURATED | 2 years | Archive to S3 after 2 years | Audit trail |
| ANALYTICS | 5 years | Archive to S3 after 5 years | Business analytics |
| INTELLIGENCE | 1 year | Delete after 1 year | Query optimization |
| GOVERNANCE | 7 years | Maintain in Snowflake | Compliance (HIPAA, GDPR) |

---

## Access Control Matrix

| Role | RAW | CURATED | ANALYTICS | SEARCH | INTELLIGENCE | GOVERNANCE |
|------|-----|---------|-----------|--------|--------------|------------|
| Data Engineer | RW | RW | RW | RW | RW | RW |
| Analytics Engineer | R | R | RW | R | R | R |
| Data Analyst | - | R | R | R | - | R |
| Business User | - | - | R | R | - | - |
| Data Steward | R | R | R | R | R | RW |

**Legend:** R = Read, W = Write, RW = Read/Write, - = No access

---

## Compliance & Audit

### HIPAA Compliance

**Applicable to:**
- Provider NPI (limited dataset identifier)
- Beneficiary counts (aggregated only, < 11 suppressed)

**Safeguards:**
1. Access controls via Snowflake RBAC
2. Audit logging enabled (ACCOUNTADMIN level)
3. No direct PHI in dataset
4. Encryption at rest and in transit

### GDPR Compliance

**Not applicable:** Dataset contains only US providers and aggregated data. No EU data subjects.

### CMS Data Use Agreement

**Requirements:**
1. Attribution: "Source: Centers for Medicare & Medicaid Services"
2. No re-identification attempts
3. Suppression of small cell sizes honored
4. Public use file only (no restricted data)

---

## Change Log

### Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-01-15 | Initial data dictionary created | Data Governance Team |
| 1.1.0 | 2024-01-26 | Enhanced with industry standards (DAMA-DMBOK, ISO 8000) | Data Governance Team |

---

## Related Documentation

- [Metric Catalog](../reference/metric_catalog.md) - Business metric definitions
- [Semantic Model Lifecycle](semantic_model_lifecycle.md) - Model versioning
- [Data Model](../implementation/data_model.md) - ERD and schema architecture
- [Getting Started](../implementation/getting-started.md) - Deployment guide

---

## Standards References

### Industry Frameworks
- **DAMA-DMBOK 2.0:** Data Management Body of Knowledge (www.dama.org)
- **ISO 8000-2:** Data Quality Standard
- **DCAM:** Data Management Capability Assessment Model
- **NIST:** National Institute of Standards and Technology Data Management

### Compliance Frameworks
- **HIPAA:** Health Insurance Portability and Accountability Act
- **GDPR:** General Data Protection Regulation
- **CMS Data Standards:** Centers for Medicare & Medicaid Services

### Healthcare Standards
- **NPPES:** National Plan and Provider Enumeration System (NPI validation)
- **FDA GUDID:** Global Unique Device Identification Database
- **CMS Public Use Files:** Medicare claims data standards

---

## Contact & Ownership

**Data Governance Team:** governance@example.com
**Data Steward (Healthcare):** healthcare.steward@example.com
**Data Engineer Owner:** dataeng@example.com
**Questions:** Submit issue to Data Governance board
