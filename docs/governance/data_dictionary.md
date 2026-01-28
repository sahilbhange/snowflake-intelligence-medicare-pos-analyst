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
| CMS-DMEPOS-001 | CMS DMEPOS Referring Provider | Centers for Medicare & Medicaid Services | Annual | Provider + HCPCS + Year |
| FDA-GUDID-001 | FDA Global Unique Device Identification Database | U.S. Food and Drug Administration | Monthly | Device Identifier (DI) |

### Data Acquisition

**CMS DMEPOS:**
- **Method:** API download (JSON)
- **URL:** https://data.cms.gov/provider-summary-by-type-of-service/medicare-dmepos-referring-provider/medicare-dmepos-referring-provider
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

---

## Data Dictionary: RAW Layer

### RAW.RAW_DMEPOS

**Purpose:** Raw landing for CMS DMEPOS JSON
**Classification:** Public
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Description |
|--------|-----------|----------|----------------|-------------|
| raw_data | VARIANT | No | Public | Full JSON payload from CMS API |
| loaded_at | TIMESTAMP | No | Internal | Timestamp of data ingestion |

**Quality Rules:**
- Must be valid JSON
- Loaded_at must be within last 24 hours of run time

**Lineage:**
- **Source:** CMS DMEPOS API
- **Transformation:** None (raw ingestion)
- **Downstream:** CURATED.DMEPOS_CLAIMS

---

### RAW.RAW_GUDID_DEVICE

**Purpose:** Raw landing for FDA GUDID device catalog
**Classification:** Public
**Owner:** Data Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Description |
|--------|-----------|----------|----------------|-------------|
| raw_data | VARIANT | No | Public | Full device record from FDA bulk file |
| loaded_at | TIMESTAMP | No | Internal | Timestamp of data ingestion |

**Quality Rules:**
- Must contain primary_di field
- Device publish date must be valid

**Lineage:**
- **Source:** FDA GUDID Bulk Download
- **Transformation:** None (raw ingestion)
- **Downstream:** CURATED.GUDID_DEVICES

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
| referring_npi | NUMBER(10,0) | No | Confidential | National Provider Identifier for referring physician | 10-digit NPI | 1003000126 |
| provider_last_name | STRING | Yes | Confidential | Provider's last name (organization name for entities) | Alpha characters | SMITH, JONES |
| provider_first_name | STRING | Yes | Confidential | Provider's first name (null for organizations) | Alpha characters | JOHN, MARY |
| provider_mi | STRING | Yes | Confidential | Provider's middle initial | Single character | J, M |
| provider_credentials | STRING | Yes | Internal | Provider credentials (MD, DO, NP, PA) | Standard credentials | MD, DO, NP |
| provider_gender | STRING | Yes | Internal | Provider gender | M, F, or null | M, F |
| provider_entity_type | STRING | Yes | Internal | Individual or Organization | I (Individual), O (Organization) | I, O |
| provider_street1 | STRING | Yes | Confidential | Provider street address line 1 | Valid US address | 123 MAIN ST |
| provider_street2 | STRING | Yes | Confidential | Provider street address line 2 | Valid US address | SUITE 100 |
| provider_city | STRING | Yes | Internal | Provider city | Valid US city | LOS ANGELES |
| provider_zip | STRING | Yes | Internal | Provider ZIP code | 5 or 9 digit ZIP | 90001, 90001-1234 |
| provider_state | STRING | Yes | Public | Two-letter US state code | US state abbreviations | CA, TX, NY |
| provider_country | STRING | Yes | Public | Country code | US (currently only US) | US |
| provider_specialty_code | STRING | Yes | Internal | Medicare specialty code | CMS specialty codes | 11, 50 |
| provider_specialty_desc | STRING | Yes | Internal | Medicare specialty description | CMS specialty descriptions | Internal Medicine, Nurse Practitioner |
| provider_specialty_source | STRING | Yes | Internal | Source of specialty classification | CMS, NPPES | CMS |
| hcpcs_code | STRING | No | Public | Healthcare Common Procedure Coding System code | 5-character alphanumeric | E1390, A4253 |
| hcpcs_description | STRING | Yes | Public | Description of HCPCS code | Free text | Oxygen concentrator |
| rbcs_id | STRING | Yes | Internal | RBCS (Revenue Bearer Code System) identifier | Alphanumeric | R12345 |
| supplier_rental_indicator | STRING | Yes | Public | Rental equipment flag (at HCPCS level) | Y (Yes), N (No), null | Y, N |
| total_suppliers | NUMBER | Yes | Internal | Count of unique suppliers | >= 0 | 5, 12 |
| total_supplier_benes | NUMBER | Yes | Confidential | Count of unique beneficiaries served (aggregated) | >= 0, may be suppressed | 45, 120 |
| total_supplier_claims | NUMBER | Yes | Public | Total count of claims | >= 0 | 100, 500 |
| total_supplier_services | NUMBER | Yes | Public | Total count of services rendered | >= total_supplier_claims | 150, 600 |
| avg_supplier_submitted_charge | NUMBER(10,2) | Yes | Public | Average submitted charge amount (USD) | >= 0 | 125.50 |
| avg_supplier_medicare_allowed | NUMBER(10,2) | Yes | Public | Average Medicare allowed amount (USD) | >= 0, <= avg_submitted_charge | 85.25 |
| avg_supplier_medicare_payment | NUMBER(10,2) | Yes | Public | Average Medicare payment amount (USD) | >= 0, <= avg_allowed | 68.20 |
| avg_supplier_medicare_standard | NUMBER(10,2) | Yes | Public | Average Medicare standardized payment (USD) | >= 0 | 70.00 |
| loaded_at | TIMESTAMP | No | Internal | Timestamp of ETL load | System timestamp | 2024-01-20 10:30:00 |

**Business Rules:**
1. **Grain:** One row per unique (referring_npi, hcpcs_code) combination
2. **Deduplication:** Latest record wins (QUALIFY ROW_NUMBER() OVER ... = 1)
3. **Suppression:** CMS suppresses beneficiary counts < 11 for privacy
4. **Payment hierarchy:** avg_submitted_charge >= avg_allowed >= avg_payment
5. **Services >= Claims:** Services count must be >= claims count
6. **NPI validation:** NPIs must be 10 digits and valid per NPPES registry

**Data Quality Checks:**
- No nulls in referring_npi, hcpcs_code
- avg_payment <= avg_allowed <= avg_submitted_charge
- total_supplier_services >= total_supplier_claims
- provider_state in valid US state list

**Lineage:**
- **Source:** RAW.RAW_DMEPOS
- **Transformation:** JSON parsing, type casting, deduplication
- **SQL:** sql/transform/build_curated_model.sql
- **Downstream:** ANALYTICS.DIM_PROVIDER, ANALYTICS.FACT_DMEPOS_CLAIMS

**Compliance Notes:**
- NPIs are confidential per HIPAA (limited disclosure)
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
| di_number | STRING | No | Public | Device Identifier (DI) - primary key | 14-digit GTIN or HRI | 00627595000712 |
| brand_name | STRING | Yes | Public | Brand or trade name of device | Free text | Medline, Invacare |
| version_or_model_number | STRING | Yes | Public | Device version or model number | Alphanumeric | Model-X100 |
| catalog_number | STRING | Yes | Public | Manufacturer catalog number | Alphanumeric | CAT-12345 |
| company_name | STRING | Yes | Public | Device manufacturer or labeler | Free text | MEDLINE INDUSTRIES, INC. |
| device_description | STRING | Yes | Public | Textual description of device | Free text | Portable oxygen concentrator |
| device_count_in_base_package | NUMBER | Yes | Internal | Count of devices in package | >= 1 | 1, 12 |
| device_status | STRING | Yes | Internal | Regulatory status | Active, Inactive | Active |
| device_publish_date | DATE | Yes | Internal | FDA publish date | Valid date | 2023-05-15 |
| device_record_status | STRING | Yes | Internal | Record status in GUDID | Published, Updated | Published |
| commercial_distribution_status | STRING | Yes | Public | Distribution status | In Commercial Distribution, Not in Commercial Distribution | In Commercial Distribution |
| rx_or_otc | STRING | Yes | Public | Prescription or over-the-counter | Rx, OTC | Rx |
| loaded_at | TIMESTAMP | No | Internal | Timestamp of ETL load | System timestamp | 2024-01-20 11:00:00 |

**Business Rules:**
1. **Grain:** One row per unique di_number
2. **Primary key:** di_number (14-digit GTIN format)
3. **Active devices:** commercial_distribution_status = 'In Commercial Distribution'
4. **Deduplication:** Latest publish date wins

**Data Quality Checks:**
- di_number must be unique
- device_publish_date must be valid
- No nulls in di_number, company_name, device_description

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
**Type:** Slowly Changing Dimension (SCD Type 1)
**Classification:** Confidential
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Business Definition | Synonyms |
|--------|-----------|----------|----------------|---------------------|----------|
| referring_npi | NUMBER(10,0) | No | Confidential | National Provider Identifier (primary key) | NPI, provider_id |
| provider_name | STRING | Yes | Confidential | Full provider name (concatenated) | name, provider |
| provider_specialty_desc | STRING | Yes | Internal | Provider specialty | specialty, type |
| provider_city | STRING | Yes | Internal | Provider city | city |
| provider_state | STRING | Yes | Public | Provider state | state, location |
| provider_zip | STRING | Yes | Internal | Provider ZIP code | zip, postal_code |

**Business Rules:**
- Derived from CURATED.DMEPOS_CLAIMS (distinct providers)
- SCD Type 1: Current state only, no history

**Quality Rules:**
- No duplicate NPIs
- All NPIs in CURATED.DMEPOS_CLAIMS must exist

**Lineage:**
- **Source:** CURATED.DMEPOS_CLAIMS
- **Transformation:** SELECT DISTINCT, name concatenation
- **SQL:** sql/transform/build_curated_model.sql

---

### ANALYTICS.DIM_DEVICE

**Purpose:** Device dimension for analytics
**Type:** Slowly Changing Dimension (SCD Type 1)
**Classification:** Public
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward

| Column | Data Type | Nullable | Classification | Business Definition | Synonyms |
|--------|-----------|----------|----------------|---------------------|----------|
| di_number | STRING | No | Public | Device Identifier (primary key) | DI, device_id |
| brand_name | STRING | Yes | Public | Device brand | brand, manufacturer_name |
| device_description | STRING | Yes | Public | Device description | description, device_name |
| company_name | STRING | Yes | Public | Manufacturer | manufacturer, company |
| device_description_embedding | VECTOR(FLOAT, 1024) | Yes | Internal | Arctic embedding for semantic search | embedding, vector |

**Business Rules:**
- Only active devices (commercial_distribution_status = 'In Commercial Distribution')
- Embeddings generated for semantic similarity search

**Quality Rules:**
- No duplicate DIs
- device_description must not be null if embedding exists

**Lineage:**
- **Source:** CURATED.GUDID_DEVICES
- **Transformation:** Filtering, embedding generation
- **SQL:** sql/transform/build_curated_model.sql

---

### ANALYTICS.FACT_DMEPOS_CLAIMS

**Purpose:** Analytics-ready fact table for claims analysis
**Type:** Aggregate Fact Table
**Classification:** Public (aggregated)
**Owner:** Analytics Engineering Team
**Steward:** Healthcare Data Steward
**Grain:** One row per provider + HCPCS code

| Column | Data Type | Nullable | Classification | Business Definition | Aggregation Type |
|--------|-----------|----------|----------------|---------------------|------------------|
| referring_npi | NUMBER(10,0) | No | Confidential | Provider identifier (FK to DIM_PROVIDER) | Dimension |
| hcpcs_code | STRING | No | Public | HCPCS code | Dimension |
| provider_specialty_desc_ref | STRING | Yes | Internal | Provider specialty (denormalized) | Dimension |
| device_brand_name | STRING | Yes | Public | Device brand (joined from DIM_DEVICE) | Dimension |
| total_supplier_claims | NUMBER | Yes | Public | Total claims | SUM |
| total_supplier_services | NUMBER | Yes | Public | Total services | SUM |
| total_supplier_benes | NUMBER | Yes | Confidential | Total beneficiaries (suppressed if < 11) | SUM |
| avg_supplier_medicare_allowed | NUMBER(10,2) | Yes | Public | Average allowed amount | AVG |
| avg_supplier_medicare_payment | NUMBER(10,2) | Yes | Public | Average payment | AVG |

**Business Rules:**
- Enriched with provider details (denormalized for performance)
- Optional join to DIM_DEVICE via hcpcs_code (demo simplification)
- Pre-aggregated for fast query performance

**Quality Rules:**
- Referential integrity: referring_npi exists in DIM_PROVIDER
- avg_payment <= avg_allowed
- total_services >= total_claims

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
| hcpcs_code | STRING | No | HCPCS code (primary key) |
| hcpcs_description | STRING | Yes | Code description |
| supplier_rental_indicator | STRING | Yes | Rental flag (Y/N) |
| hcpcs_code_lower | STRING | Yes | Lowercase code for search |

**Lineage:**
- **Source:** CURATED.DMEPOS_CLAIMS
- **Transformation:** DISTINCT, lowercase normalization
- **Downstream:** SEARCH.HCPCS_SEARCH_SVC

---

### SEARCH.DEVICE_SEARCH_DOCS

**Purpose:** Device search corpus for Cortex Search
**Classification:** Public
**Owner:** AI/ML Engineering Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| di_number | STRING | No | Device identifier (primary key) |
| device_description | STRING | Yes | Device description |
| brand_name | STRING | Yes | Brand name |
| company_name | STRING | Yes | Manufacturer |

**Lineage:**
- **Source:** ANALYTICS.DIM_DEVICE
- **Transformation:** SELECT for search attributes
- **Downstream:** SEARCH.DEVICE_SEARCH_SVC

---

## Data Dictionary: INTELLIGENCE Layer

### INTELLIGENCE.ANALYST_EVAL_SET

**Purpose:** Evaluation questions for semantic model testing
**Classification:** Internal
**Owner:** AI/ML Engineering Team
**Steward:** Data Quality Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| question_id | STRING | No | Unique question identifier |
| question_text | STRING | No | Natural language question |
| expected_sql_pattern | STRING | Yes | Expected SQL pattern for validation |
| complexity | STRING | Yes | simple, moderate, complex |
| created_at | TIMESTAMP | No | Creation timestamp |

**Quality Rules:**
- question_text must be valid natural language
- complexity must be one of: simple, moderate, complex

---

### INTELLIGENCE.ANALYST_QUERY_LOG

**Purpose:** Query logging for Cortex Analyst usage
**Classification:** Internal
**Owner:** AI/ML Engineering Team
**Retention:** 1 year

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| query_id | STRING | No | Unique query identifier |
| user_name | STRING | Yes | User who executed query |
| question_text | TEXT | Yes | User's natural language question |
| generated_sql | TEXT | Yes | AI-generated SQL |
| was_successful | BOOLEAN | Yes | Query success flag |
| error_message | TEXT | Yes | Error details if failed |
| query_timestamp | TIMESTAMP | No | Execution timestamp |

**Compliance:**
- PII scrubbed from logs
- 1-year retention per data governance policy

---

## Data Dictionary: GOVERNANCE Layer

### GOVERNANCE.COLUMN_METADATA

**Purpose:** Column-level metadata catalog
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| schema_name | STRING | No | Schema name |
| table_name | STRING | No | Table name |
| column_name | STRING | No | Column name |
| business_name | STRING | Yes | Business-friendly name |
| business_definition | STRING | Yes | Business definition |
| data_type | STRING | Yes | Snowflake data type |
| is_pii | BOOLEAN | Yes | Contains PII flag |
| contains_phi | BOOLEAN | Yes | Contains PHI flag |
| gdpr_classification | STRING | Yes | GDPR classification |
| data_classification | STRING | Yes | Public, Internal, Confidential, Restricted |
| valid_values | STRING | Yes | List of valid values |
| sample_values | STRING | Yes | Example values |
| owner | STRING | Yes | Data owner |
| steward | STRING | Yes | Data steward |
| created_at | TIMESTAMP | No | Record creation timestamp |
| updated_at | TIMESTAMP | No | Last update timestamp |

**Population:**
- Manually curated for all CURATED and ANALYTICS tables
- Reviewed quarterly

---

### GOVERNANCE.DATA_LINEAGE

**Purpose:** Data lineage tracking
**Classification:** Internal
**Owner:** Data Governance Team

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| target_schema | STRING | No | Downstream schema |
| target_table | STRING | No | Downstream table |
| source_schema | STRING | No | Upstream schema |
| source_table | STRING | No | Upstream table |
| transformation_type | STRING | Yes | direct_copy, filter, aggregate, join, enrich |
| transformation_sql | TEXT | Yes | SQL script reference |
| last_refresh | TIMESTAMP | Yes | Last refresh timestamp |

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
| schema_name | STRING | No | Target schema |
| table_name | STRING | No | Target table |
| check_type | STRING | No | row_count, null_check, uniqueness, referential_integrity |
| check_sql | TEXT | No | SQL for quality check |
| severity | STRING | No | critical, warning, info |
| last_run | TIMESTAMP | Yes | Last execution timestamp |
| last_result | STRING | Yes | pass, fail |
| fail_count | NUMBER | Yes | Count of failures |

**Quality Check Types:**
1. **Row Count:** Minimum expected rows
2. **Null Check:** Critical columns must not be null
3. **Uniqueness:** Primary keys must be unique
4. **Referential Integrity:** Foreign keys must exist
5. **Range Check:** Values within expected ranges
6. **Pattern Match:** Values match expected patterns (e.g., NPI format)

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

1. **Payment hierarchy:** avg_payment <= avg_allowed <= avg_submitted_charge
2. **Service/claim relationship:** total_services >= total_claims
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
