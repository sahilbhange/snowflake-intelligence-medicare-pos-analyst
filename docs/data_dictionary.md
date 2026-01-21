# Data Dictionary (Scaffold)

This dictionary is intentionally compact and aligned to the Medium story: source data, curated model, semantic layer, and search services.

## 1) Sources

| Source | Description | Grain | Primary Keys |
| --- | --- | --- | --- |
| CMS DMEPOS Referring Provider | Public claims data for DMEPOS by referring provider and HCPCS code | Provider + HCPCS | `Rfrg_NPI`, `HCPCS_CD` |
| FDA GUDID | Public device catalog | Device identifier (DI) | `primary_di` |

## 2) Raw staging tables

| Table | Source | Notes |
| --- | --- | --- |
| `ANALYTICS.RAW_DMEPOS` | CMS DMEPOS API | JSON ingested into VARIANT | 
| `ANALYTICS.RAW_GUDID_DEVICE` | FDA GUDID | Pipe-delimited device file |
| `ANALYTICS.RAW_GUDID_IDENTIFIERS` | FDA GUDID | Device identifiers and packaging |
| `ANALYTICS.RAW_GUDID_CONTACTS` | FDA GUDID | Manufacturer contacts |
| `ANALYTICS.RAW_GUDID_PRODUCT_CODES` | FDA GUDID | Product code mapping |
| `ANALYTICS.RAW_GUDID_DEVICE_SIZES` | FDA GUDID | Device sizing attributes |
| `ANALYTICS.RAW_GUDID_ENVIRONMENTAL_CONDITIONS` | FDA GUDID | Storage and handling |
| `ANALYTICS.RAW_GUDID_PREMARKET_SUBMISSIONS` | FDA GUDID | Submission numbers |
| `ANALYTICS.RAW_GUDID_GMDN_TERMS` | FDA GUDID | GMDN definitions |
| `ANALYTICS.RAW_GUDID_STERILIZATION_METHODS` | FDA GUDID | Sterilization methods |

## 3) Curated tables

### `ANALYTICS.DMEPOS_CLAIMS`

| Column | Description | Example |
| --- | --- | --- |
| `referring_npi` | Referring provider NPI | `1003000126` |
| `provider_state` | Provider state | `CA` |
| `hcpcs_code` | HCPCS code | `E1390` |
| `hcpcs_description` | HCPCS description | `Oxygen concentrator...` |
| `supplier_rental_indicator` | Rental flag | `Y` |
| `total_supplier_claims` | Total claims | `34` |
| `avg_supplier_medicare_payment` | Avg payment | `71.65` |

### `ANALYTICS.GUDID_DEVICES`

| Column | Description | Example |
| --- | --- | --- |
| `di_number` | Device identifier (DI) | `00627595000712` |
| `brand_name` | Device brand | `Medline` |
| `company_name` | Manufacturer | `MEDLINE INDUSTRIES, INC.` |
| `device_description` | Device description | `Wheelchair...` |

## 4) Dimensions and facts

### `ANALYTICS.DIM_PROVIDER`

| Column | Description |
| --- | --- |
| `referring_npi` | Provider NPI |
| `provider_specialty_desc` | Specialty description |
| `provider_city` | Provider city |

### `ANALYTICS.FACT_DMEPOS_CLAIMS`

| Column | Description |
| --- | --- |
| `hcpcs_code` | HCPCS code |
| `total_supplier_claims` | Total claims |
| `total_supplier_services` | Total services |
| `avg_supplier_medicare_allowed` | Avg allowed amount |

## 5) Semantic layer (Cortex Analyst)

Semantic model file: `models/DMEPOS_SEMANTIC_MODEL.yaml`

### Core metrics

| Metric | Description |
| --- | --- |
| `TOTAL_CLAIMS_SUM` | Total claims across records |
| `AVG_MEDICARE_PAYMENT` | Average Medicare payment |
| `PAYMENT_TO_ALLOWED_RATIO` | Avg payment / avg allowed |

### Core dimensions

| Dimension | Description |
| --- | --- |
| `HCPCS_CODE` | Procedure code |
| `PROVIDER_SPECIALTY_DESC` | Provider specialty |
| `PROVIDER_STATE` | Provider state |

## 6) Search corpuses (Cortex Search)

| Corpus table | Primary use |
| --- | --- |
| `HCPCS_SEARCH_DOCS` | HCPCS definitions and rental indicators |
| `DEVICE_SEARCH_DOCS` | GUDID device catalog |
| `PROVIDER_SEARCH_DOCS` | Provider directory |

## 7) Data quality checks (scaffold)

- Row count checks for `DMEPOS_CLAIMS` and `GUDID_DEVICES`.
- Null checks on `hcpcs_code` and `referring_npi`.
- Duplicate checks on `di_number`.

## 8) Glossary (scaffold)

- **DMEPOS**: Durable Medical Equipment, Prosthetics, Orthotics, and Supplies.
- **HCPCS**: Healthcare Common Procedure Coding System.
- **GUDID**: Global Unique Device Identification Database.
