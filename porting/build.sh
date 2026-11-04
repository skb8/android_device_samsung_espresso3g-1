#!/usr/bin/env bash
# Reproducible attempt runner, not a claim that this port builds or boots.
set -eo pipefail

device_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
android_root="${1:-$PWD}"
android_root="$(cd -- "$android_root" && pwd)"
cd -- "$android_root"
log_dir="$android_root/out/espresso-port-logs"
mkdir -p "$log_dir"

{
    echo "Experimental espresso3g / LineageOS 20 build attempt"
    date -u '+UTC %Y-%m-%d %H:%M:%S'
    git -C "$device_dir" rev-parse HEAD
    df -h "$android_root"
    if [[ ! -f build/envsetup.sh ]]; then
        echo "BLOCKED: missing Android sources (build/envsetup.sh)."
        echo "Follow porting/README.md to sync the pinned source composition."
        exit 2
    fi
    for required in device/samsung/espressowifi/BoardConfigCommon.mk \
                    hardware/ti/omap4/BoardConfigCommon.mk \
                    kernel/ti/omap4/arch/arm/configs/espresso_defconfig \
                    vendor/samsung/espresso3g/espresso3g-vendor.mk; do
        if [[ ! -f "$required" ]]; then
            echo "BLOCKED: missing dependency: $required"
            exit 2
        fi
    done
    bash "$device_dir/porting/prepare.sh" "$android_root"
    # Android envsetup is not compatible with shell nounset.
    source build/envsetup.sh
    lunch lineage_espresso3g-userdebug
    m -j"${ESPRESSO_JOBS:-4}" bacon
} 2>&1 | tee "$log_dir/build.log"
