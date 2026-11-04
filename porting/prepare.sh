#!/usr/bin/env bash
# Run from the root of the synced Android checkout.
set -euo pipefail

device_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
android_root="${1:-$PWD}"
android_root="$(cd -- "$android_root" && pwd)"
common_dir="$android_root/device/samsung/espressowifi"
patch_dir="$device_dir/porting/patches/espressowifi"

if [[ ! -f "$common_dir/BoardConfigCommon.mk" ]]; then
    echo "Missing shared espresso tree: $common_dir" >&2
    exit 1
fi

for patch_file in "$patch_dir"/*.patch; do
    if git -C "$common_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
        echo "Already applied: ${patch_file##*/}"
    else
        git -C "$common_dir" apply --check "$patch_file"
        git -C "$common_dir" apply "$patch_file"
        echo "Applied: ${patch_file##*/}"
    fi
done
