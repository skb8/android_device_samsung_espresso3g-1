#!/usr/bin/env bash
# Run from the root of the synced Android checkout or provide it as $1.
set -euo pipefail

device_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
android_root="${1:-$PWD}"
android_root="$(cd -- "$android_root" && pwd)"

declare -A TARGET_REPOS=(
    ["espressowifi"]="device/samsung/espressowifi"
    ["external_bouncycastle"]="external/bouncycastle"
    ["external_conscrypt"]="external/conscrypt"
    ["external_grpc_grpc_java"]="external/grpc-grpc-java"
    ["external_libchrome"]="external/libchrome"
    ["external_libopus"]="external/libopus"
    ["external_okhttp"]="external/okhttp"
    ["external_robolectric"]="external/robolectric"
    ["frameworks_proto_logging"]="frameworks/proto_logging"
    ["hardware_lineage_interfaces"]="hardware/lineage/interfaces"
    ["vendor_lineage"]="vendor/lineage"
)

patches_base="$device_dir/porting/patches"

if [[ ! -d "$patches_base" ]]; then
    echo "Patches directory not found: $patches_base" >&2
    exit 1
fi

echo "==> Applying porting patches for espresso3g..."

for patch_subdir in "$patches_base"/*; do
    [[ -d "$patch_subdir" ]] || continue
    sub_name="$(basename "$patch_subdir")"
    target_rel="${TARGET_REPOS[$sub_name]:-}"

    if [[ -z "$target_rel" ]]; then
        echo "Warning: No repository mapping for $sub_name, skipping." >&2
        continue
    fi

    target_dir="$android_root/$target_rel"
    if [[ ! -d "$target_dir" ]]; then
        echo "Warning: Target repository directory does not exist: $target_dir, skipping." >&2
        continue
    fi

    echo "-> Checking patches for $sub_name ($target_rel)"
    for patch_file in "$patch_subdir"/*.patch; do
        [[ -f "$patch_file" ]] || continue
        patch_name="$(basename "$patch_file")"

        if git -C "$target_dir" apply --reverse --check "$patch_file" 2>/dev/null; then
            echo "   [Already applied] $patch_name"
        else
            git -C "$target_dir" apply --check "$patch_file"
            git -C "$target_dir" apply "$patch_file"
            echo "   [Applied] $patch_name"
        fi
    done
done

echo "==> All porting patches verified/applied successfully."
