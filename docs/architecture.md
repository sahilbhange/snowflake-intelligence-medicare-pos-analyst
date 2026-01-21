# Architecture (Scaffold)

This document pairs with the Medium story on Snowflake Intelligence: data modeling, semantic layer, data dictionary, and search services.

## 1) High-level flow

1. **Source data**
   - CMS DMEPOS provider claims (API download)
   - FDA GUDID device catalog (bulk release)
2. **Raw landing**
   - JSON and delimited files loaded into Snowflake stages and raw tables
3. **Curated model**
   - `DMEPOS_CLAIMS` and `GUDID_DEVICES` tables
   - Provider/device dimensions and a claims fact view
4. **Semantic layer**
   - `DMEPOS_SEMANTIC_MODEL` for Cortex Analyst
5. **Search services**
   - HCPCS definitions, device catalog, provider directory
6. **Snowflake Intelligence UX**
   - Analyst for quantitative questions
   - Search for definitions and catalog lookups

## 2) Diagram placeholder

Use `docs/datamodel.png` or replace with a new diagram when writing the article.

## 3) Key Snowflake objects

| Layer | Object | Purpose |
| --- | --- | --- |
| Raw | `RAW_DMEPOS`, `RAW_GUDID_DEVICE` | Source landing tables |
| Curated | `DMEPOS_CLAIMS`, `GUDID_DEVICES` | Clean tables |
| Dimensions | `DIM_PROVIDER`, `DIM_DEVICE` | Lookup entities |
| Facts | `FACT_DMEPOS_CLAIMS` | Analytics-ready view |
| Semantic | `DMEPOS_SEMANTIC_MODEL` | Analyst model |
| Search | `HCPCS_SEARCH_SVC`, `DEVICE_SEARCH_SVC`, `PROVIDER_SEARCH_SVC` | Search services |

## 4) Medium story alignment

- **Part 1: Source data and raw ingestion**
  - Show data acquisition and staging.
- **Part 2: Curated model and data dictionary**
  - Explain the star-style model and the dictionary scaffold.
- **Part 3: Semantic layer and search services**
  - Show how Analyst and Search split workloads.
- **Part 4: Demo walkthrough**
  - Use example prompts from `README.md`.

## 5) Future extensions

- Add a domain dictionary for HCPCS and RBCS categories.
- Add QA checks with a data validation framework.
- Add a scheduled refresh pipeline (Tasks + Streams).
