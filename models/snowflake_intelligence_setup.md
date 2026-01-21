# Snowflake Intelligence Setup

Use this guide after you have created the search services and semantic model.

## Prerequisites

- `MEDICARE_POS_DB.ANALYTICS` is created.
- Cortex Search services exist:
  - `HCPCS_SEARCH_SVC`
  - `DEVICE_SEARCH_SVC`
  - `PROVIDER_SEARCH_SVC`
- The semantic model `DMEPOS_SEMANTIC_MODEL.yaml` is uploaded.

## Add search services in Snowflake Intelligence

1. Open Snowsight → **AI & ML** → **Snowflake Intelligence**.
2. Click **Add Source** and choose **Cortex Search Service**.
3. Add each service with these settings:

| Service | Display Name | Description |
| --- | --- | --- |
| `HCPCS_SEARCH_SVC` | HCPCS Code Definitions | HCPCS definitions and rental flags. |
| `DEVICE_SEARCH_SVC` | Medical Device Catalog | FDA GUDID device catalog entries. |
| `PROVIDER_SEARCH_SVC` | Provider Directory | Provider specialties and locations. |

Use `MEDICARE_POS_DB` and `ANALYTICS` for database/schema. Keep max results at 5.

## Quick validation prompts

- HCPCS: "What is HCPCS code E1390?"
- Devices: "Find oxygen concentrators"
- Providers: "Find endocrinologists in California"
- Analyst: "Top 10 states by claim volume"

If a source does not appear, confirm grants on the search services and the semantic model.
