#!/bin/bash

# Loop through command line options
# Set REBOOT flag if "--reboot" option is provided
# Set USE_REMOUNT flag if "--use_remount" option is provided
while getopts ":-:" o; do
    case "${OPTARG}" in
    reboot)
        REBOOT=1
        ;;
    use_remount)
        USE_REMOUNT=1
        ;;
    esac
done

# Wait for the device to be available and then run root command
adb wait-for-device root

# Unmount /system/bin and /system/etc if /system is mounted as tmpfs
adb wait-for-device shell "mount | grep -q ^tmpfs\ on\ /system && umount -fl /system/{bin,etc} 2>/dev/null"

# Remount /system as read-write if USE_REMOUNT flag is set, otherwise check if /system has available blocks and mount it as read-write
if [[ "${USE_REMOUNT}" = "1" ]]; then
    adb wait-for-device shell "remount"
elif [[ "$(adb shell stat -f --format %a /system)" = "0" ]]; then
    echo "ERROR: /system has 0 available blocks, consider using --use_remount"
    exit -1
else
    adb wait-for-device shell "stat --format %m /system | xargs mount -o rw,remount"
fi

# Push necessary files to the device
adb wait-for-device push system/addon.d/60-ih8sn.sh /system/addon.d/
adb wait-for-device push system/bin/ih8sn /system/bin/
adb wait-for-device push system/etc/init/ih8sn.rc /system/etc/init/

# Get device information
MODEL=$(adb shell getprop ro.product.model | tr ' ' '_' | sed 's/_*$//')
SERIALNO=$(adb shell getprop ro.boot.serialno | tr ' ' '_' | sed 's/_*$//')
PRODUCT=$(adb shell getprop ro.build.product | tr ' ' '_' | sed 's/_*$//')

DEFAULT_CONFIG=system/etc/ih8sn.conf

# Check if device-specific configuration file exists, otherwise use default configuration file
if [[ -f "$DEFAULT_CONFIG.${MODEL}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${MODEL}
elif [[ -f "$DEFAULT_CONFIG.${SERIALNO}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${SERIALNO}
elif [[ -f "$DEFAULT_CONFIG.${PRODUCT}" ]]; then
    CONFIG=$DEFAULT_CONFIG.${PRODUCT}
else
    CONFIG=$DEFAULT_CONFIG
fi

# Push the configuration file to the device
adb wait-for-device push "$CONFIG" /system/etc/ih8sn.conf

# Get SDK version, determine architecture, and push libkeystore-attestation-application-id.so file to the device if necessary
sdk_version=$(adb shell getprop ro.build.version.sdk)
libkeystore="libkeystore-attestation-application-id.so"
arch=$(adb shell getprop ro.product.cpu.abi | grep -o -E 'arm64-v8a|armeabi-v7a')
if [ "$arch" = "arm64-v8a" ]; then
    libdir=lib64
else
    libdir=lib
fi

if [[ -f "system/$libdir/$sdk_version/$libkeystore" ]]; then
    if $(grep -q '^FORCE_BASIC_ATTESTATION=1' "$CONFIG") || ! $(grep -q '^FORCE_BASIC_ATTESTATION=0' "$CONFIG"); then
        adb wait-for-device push "system/$libdir/$sdk_version/$libkeystore" /system/$libdir/
    fi
fi

# Reboot the device if REBOOT
if [[ "${REBOOT}" = "1" ]]; then
    adb wait-for-device reboot
fi

read -r -p "Press any key to exit..." && exit
