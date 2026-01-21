# Project Overview

This doc explains the datasets, curated model, semantic layer, and Cortex Search services, and how they work together in Snowflake Intelligence.

## 1) Datasets

### CMS DMEPOS (claims)
- **Source**: CMS DMEPOS Referring Provider dataset.
- **What it contains**: Provider, HCPCS code, claims, services, and Medicare amounts.
- **Grain**: Referring provider + HCPCS code.

### FDA GUDID (device catalog)
- **Source**: FDA Global Unique Device Identification Database.
- **What it contains**: Device identifiers, manufacturers, descriptions, and product codes.
- **Grain**: Device identifier (DI).

## 2) Curated model and grain

The curated model is built in `scripts/step_4_data_model.sql`.

- `DMEPOS_CLAIMS` is the core claims table at provider + HCPCS grain.
- `GUDID_DEVICES` is the device catalog table keyed by DI.
- `DIM_PROVIDER` and `DIM_PRODUCT_CODE` are derived dimensions.
- `FACT_DMEPOS_CLAIMS` is a convenience view over the curated tables.

Data model diagram: `docs/data_model.md`.

## 3) Semantic layer (Cortex Analyst)

Semantic model file: `models/DMEPOS_SEMANTIC_MODEL.yaml`

- **Primary tables**: `FACT_DMEPOS_CLAIMS` and `DIM_PROVIDER`.
- **Metrics**: claims, services, beneficiaries, and payment averages.
- **Dimensions**: HCPCS, specialty, state, and provider attributes.

The semantic layer powers Analyst-style questions like:
- "Top 10 states by claim volume"
- "Average Medicare payment by specialty"

## 4) Search corpuses (Cortex Search)

Search tables and services are created from curated data:

- `HCPCS_SEARCH_DOCS` → `HCPCS_SEARCH_SVC`
- `DEVICE_SEARCH_DOCS` → `DEVICE_SEARCH_SVC`
- `PROVIDER_SEARCH_DOCS` → `PROVIDER_SEARCH_SVC`

These handle definition-style questions like:
- "What is HCPCS code E1390?"
- "Find oxygen concentrators"
- "Find endocrinologists in California"

## 5) How Analyst + Search work together

Snowflake Intelligence combines both sources:

- **Analyst** routes quantitative questions to the semantic model.
- **Search** routes definition and catalog lookups to Cortex Search.
- **Mixed questions** can use both, for example:
  - "Show wheelchair HCPCS codes and their claim volumes."

## 6) Important modeling note

The current demo joins `hcpcs_code` to `di_number` when enriching facts with devices. This is a demo-friendly link and not a strict key match. For a production model, add a true HCPCS-to-device mapping table or remove the join.
