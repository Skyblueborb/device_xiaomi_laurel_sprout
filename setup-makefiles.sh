#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=laurel_sprout
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

function vendor_imports() {
    cat <<EOF >>"$1"
        "hardware/qcom-caf/sm8150",
        "hardware/qcom-caf/wlan",
        "hardware/xiaomi",
        "vendor/qcom/opensource/commonsys/display",
        "vendor/qcom/opensource/commonsys-intf/display",
        "vendor/qcom/opensource/dataservices",
        "vendor/qcom/opensource/data-ipa-cfg-mgr-legacy-um",
        "vendor/qcom/opensource/display",
EOF
}

function lib_to_package_fixup_vendor_variants() {
    if [ "$2" != "vendor" ]; then
        return 1
    fi

    case "$1" in
        com.qualcomm.qti.dpm.api@1.0 | \
            vendor.qti.hardware.camera.device@3.2 | \
            libmmosal | \
            vendor.qti.hardware.fm@1.0 | \
            vendor.qti.imsrtpservice@3.0 | \
            camera.device@1.0-impl.so | \
            camera.device@3.2-impl.so | \
            camera.device@3.3-impl.so | \
            camera.device@3.4-impl.so | \
            camera.device@3.5-impl.so)
            echo "${1}_vendor"
            ;;
        *)
            return 1
            ;;
    esac
}

function lib_to_package_fixup() {
    lib_to_package_fixup_clang_rt_ubsan_standalone "$1" ||
        lib_to_package_fixup_proto_3_9_1 "$1" ||
        lib_to_package_fixup_vendor_variants "$@"
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}"

# Warning headers and guards
write_headers

write_makefiles "${MY_DIR}/proprietary-files.txt" true

# Finish
write_footers
