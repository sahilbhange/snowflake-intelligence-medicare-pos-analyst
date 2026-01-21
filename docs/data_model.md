# Data Model Diagram

This diagram reflects the current curated model in `scripts/step_4_data_model.sql`.

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

    GUDID_DEVICES {
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

    DMEPOS_CLAIMS ||--o{ DIM_PROVIDER : "referring_npi"
    GUDID_DEVICES ||--o{ DIM_PRODUCT_CODE : "primary_di"
    %% NOTE: The join below is a demo link (HCPCS code is not a DI).
    DMEPOS_CLAIMS }o--o{ GUDID_DEVICES : "hcpcs_code -> di_number"
```

## Notes

- `DMEPOS_CLAIMS` is the curated claims table at provider + HCPCS grain.
- `DIM_PROVIDER` is derived from `DMEPOS_CLAIMS`.
- `GUDID_DEVICES` is the curated device table keyed by DI.
- `DIM_PRODUCT_CODE` is derived from GUDID product code data.
- The `hcpcs_code -> di_number` join is a demo-friendly link, not a strict key match.
