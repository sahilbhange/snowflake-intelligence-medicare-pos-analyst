# Data Downloads

This folder stores raw source files that you load into Snowflake. The files are downloaded by helper scripts and then uploaded to Snowflake stages using `scripts/step_3_data_load.sql`.

## DMEPOS provider claims (CMS)

**What it is:** Public CMS data for DMEPOS (Durable Medical Equipment, Prosthetics, Orthotics, and Supplies) claims, grouped by referring provider and HCPCS code. This becomes the base for the claims fact table and provider dimension.

**How it is downloaded:** The script pages through the CMS API (5,000 rows per request) and writes a single JSON array to `data/dmepos_referring_provider.json`.

```bash
python data/dmepos_referring_provider_download.py --max-rows 1000000
```

Key options:
- `--max-rows` controls the total rows downloaded.
- `--out` lets you change the output file path.

## FDA GUDID device catalog

**What it is:** The FDA Global Unique Device Identification Database (GUDID) delimited full release. It includes device metadata, manufacturers, product codes, and related attributes.

**How it is downloaded:** The shell script pulls the latest configured release ZIP and extracts it to `data/gudid_delimited/`.

```bash
bash data/data_download.sh
```

Key options:
- `GUDID_RELEASE=YYYYMMDD` overrides the release date used in the download URL.

## Uploading to Snowflake

The downloads are ignored by git. Use the `PUT` commands in `scripts/step_3_data_load.sql` to upload them to the internal stages before running the copy steps.
