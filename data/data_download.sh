#!/usr/bin/env bash
set -euo pipefail

# Download FDA GUDID release files for the demo pipeline.
# Override GUDID_RELEASE if you want a different drop.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_dir="${script_dir}"

gudid_release="${GUDID_RELEASE:-20260118}"
gudid_url="https://accessgudid.nlm.nih.gov/release_files/download/AccessGUDID_Delimited_Full_Release_${gudid_release}.zip"
gudid_zip="${data_dir}/gudid_delimited_full_${gudid_release}.zip"
gudid_extract_dir="${data_dir}/gudid_delimited"

mkdir -p "$data_dir"

echo "Downloading GUDID release ${gudid_release}..."
curl -L -A "Mozilla/5.0" -o "$gudid_zip" "$gudid_url"

echo "Extracting GUDID files..."
rm -rf "$gudid_extract_dir"
mkdir -p "$gudid_extract_dir"
unzip -q "$gudid_zip" -d "$gudid_extract_dir"

echo "Done. Files saved in: $data_dir"
