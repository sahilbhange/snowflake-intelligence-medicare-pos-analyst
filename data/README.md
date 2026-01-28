# Data Setup

Download public datasets into this folder before loading into Snowflake. (Git ignored—files stay local.)

## Context

This demo analyzes **Medicare DMEPOS billing claims** (wheelchairs, oxygen, diabetic supplies, etc.) matched with **FDA device catalogs**. Combine them to understand utilization patterns, costs, and device metadata by provider.

## Quick Start

Run both downloads (~10 min total):

```bash
# 1. CMS DMEPOS claims (~50-200 MB)
python data/dmepos_referring_provider_download.py --max-rows 1000000

# 2. FDA device catalog (~300 MB)
bash data/data_download.sh
```

Files go to: `dmepos_referring_provider.json` and `gudid_delimited/`

## What You Get

| Dataset | Source | Use Case |
|---------|--------|----------|
| **CMS DMEPOS** | CMS public API | Claims by provider + device code |
| **FDA GUDID** | FDA release | Device metadata, UDI mappings, manufacturers |

## Options

- Reduce demo size: `--max-rows 100000` (CMS only)
- Custom output: `--out data/custom_name.json` (CMS only)
- Specific release: `GUDID_RELEASE=20250101 bash data/data_download.sh` (FDA only)

## Next Steps

Load to Snowflake: See `sql/ingestion/load_raw_data.sql`
