# Data Model Diagram

This diagram reflects the current model in `sql/transform/build_curated_model.sql`.
---

## Navigation

| Want This | See This |
|-----------|----------|
| 📖 **Foundation Layer Architecture** | [Subarticle 2: The Foundation Layer](../../medium/claude/subarticle_2_foundation_layer.md) |
| 💾 **Star Schema SQL** | [Build Curated Model](../../sql/transform/build_curated_model.sql) |
| 📚 **Deployment Instructions** | [Getting Started](getting-started.md) |

---


## Schema Architecture (Medallion)

| Schema | Layer | Contents |
|--------|-------|----------|
| RAW | Bronze | RAW_DMEPOS, RAW_GUDID_DEVICE, RAW_GUDID_PRODUCT_CODES |
| CURATED | Silver | DMEPOS_CLAIMS, GUDID_DEVICES |
| ANALYTICS | Gold | DIM_PROVIDER, DIM_DEVICE, DIM_PRODUCT_CODE, FACT_DMEPOS_CLAIMS |
| SEARCH | - | Cortex Search services |
| INTELLIGENCE | - | Eval sets, query logging, validation |
| GOVERNANCE | - | Metadata, lineage, quality checks |
> **📖 See Medium:** Learn how to design data architecture for AI workloads in [Subarticle 2: The Foundation Layer](../../medium/claude/subarticle_2_foundation_layer.md)

## Entity Relationship Diagram

```mermaid
erDiagram
    DMEPOS_CLAIMS {
        number referring_npi
        string hcpcs_code
        string rbcs_id
        string supplier_rental_indicator
        number total_suppliers
        number total_supplier_benes
        number total_supplier_claims
        number total_supplier_services
        decimal avg_supplier_submitted_charge
        decimal avg_supplier_medicare_allowed
        decimal avg_supplier_medicare_payment
        decimal avg_supplier_medicare_standard
    }

    DIM_PROVIDER {
        number referring_npi PK
        string provider_last_name
        string provider_first_name
        string provider_city
        string provider_state
        string provider_zip
        string provider_country
        string provider_specialty_code
        string provider_specialty_desc
        string provider_specialty_source
    }

    DIM_DEVICE {
        string di_number PK
        string brand_name
        string version_or_model_number
        string catalog_number
        string company_name
        string device_description
        string device_status
        date device_publish_date
        string commercial_distribution_status
    }

    DIM_PRODUCT_CODE {
        string primary_di PK
        string product_code
        string product_code_name
    }

    FACT_DMEPOS_CLAIMS {
        number referring_npi FK
        string hcpcs_code
        string provider_specialty_desc_ref
        string device_brand_name
    }

    DMEPOS_CLAIMS ||--o{ DIM_PROVIDER : "referring_npi"
    DIM_DEVICE ||--o{ DIM_PRODUCT_CODE : "primary_di"
    FACT_DMEPOS_CLAIMS }o--|| DIM_PROVIDER : "referring_npi"
    FACT_DMEPOS_CLAIMS }o--o| DIM_DEVICE : "hcpcs_code -> di_number"
```

## Table Details

### CURATED Layer (Silver)

| Table | Description | Source |
|-------|-------------|--------|
| `CURATED.DMEPOS_CLAIMS` | Curated claims at provider + HCPCS grain | RAW.RAW_DMEPOS |
| `CURATED.GUDID_DEVICES` | Curated device catalog | RAW.RAW_GUDID_DEVICE |

> **💾 See SQL:** Implementation details in [build_curated_model.sql](../../sql/transform/build_curated_model.sql)

### ANALYTICS Layer (Gold)

| View | Description | Source |
|------|-------------|--------|
| `ANALYTICS.DIM_PROVIDER` | Provider dimension (distinct providers) | CURATED.DMEPOS_CLAIMS |
| `ANALYTICS.DIM_DEVICE` | Device dimension | CURATED.GUDID_DEVICES |
| `ANALYTICS.DIM_PRODUCT_CODE` | Product code dimension | RAW.RAW_GUDID_PRODUCT_CODES |
| `ANALYTICS.FACT_DMEPOS_CLAIMS` | Enriched fact view (joins provider + device) | CURATED.DMEPOS_CLAIMS |

> **💾 See SQL:** Star schema fact and dimension queries in [build_curated_model.sql](../../sql/transform/build_curated_model.sql)

## Notes

- `DMEPOS_CLAIMS` is the curated claims table at provider + HCPCS grain.
- `DIM_PROVIDER` is derived from `DMEPOS_CLAIMS` (distinct providers).
- `DIM_DEVICE` is derived from `GUDID_DEVICES`.
- `DIM_PRODUCT_CODE` is derived from GUDID product code data.
- `FACT_DMEPOS_CLAIMS` enriches claims with provider and device attributes.
- The `hcpcs_code -> di_number` join is a demo-friendly link, not a strict key match.
