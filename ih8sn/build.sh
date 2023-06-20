#!/bin/bash

set -e

folder=$(dirname -- "$(readlink -f -- "$0")")
arch="$1"
tmp_dir="$folder/tmp"
script_dir="META-INF/com/google/android/"
zip_name="ih8sn-$arch.zip"
bin_out="$folder/system/bin"
ndk_version=android-ndk-r25c
nkd_download_link="https://dl.google.com/android/repository/$ndk_version-linux.zip"

declare -A toolchain=(
    ["armv7a"]="armv7a-linux-androideabi33-clang++"
    ["aarch64"]="aarch64-linux-android33-clang++"
    ["i686"]="i686-linux-android33-clang++"
    ["x86_64"]="x86_64-linux-android33-clang++"
)

if [ -z "$arch" ]; then
    $folder/$0 armv7a
    $folder/$0 aarch64
    $folder/$0 uninstall
    exit 0
elif [ -z "$arch" ] || ! [[ "$arch" =~ ^(armv7a|aarch64|i686|x86_64|uninstall)$ ]]; then
    echo "Unknown or missing architecture: $arch"
    exit 1
fi

if [ ! -d $ndk_version ]; then
    if [ ! -f $ndk_version-linux.zip ]; then
        echo "Downloading Android NDK"
        wget -q --show-progress $nkd_download_link
    fi
    echo "Extracting Android NDK"
    unzip -q $ndk_version-linux.zip
fi

export PATH=${PATH}:$folder/$ndk_version/toolchains/llvm/prebuilt/linux-x86_64/bin

mkdir -p "$bin_out" "$tmp_dir/$script_dir"

echo "Building ih8sn archive for $arch"
if [[ "$arch" =~ ^(armv7a|aarch64|i686|x86_64)$ ]]; then
    ${toolchain[$arch]} \
        -Iaosp/bionic/libc \
        -Iaosp/bionic/libc/async_safe/include \
        -Iaosp/bionic/libc/system_properties/include \
        -Iaosp/system/core/base/include \
        -Iaosp/system/core/property_service/libpropertyinfoparser/include \
        aosp/bionic/libc/bionic/system_property_api.cpp \
        aosp/bionic/libc/bionic/system_property_set.cpp \
        aosp/bionic/libc/system_properties/context_node.cpp \
        aosp/bionic/libc/system_properties/contexts_serialized.cpp \
        aosp/bionic/libc/system_properties/contexts_split.cpp \
        aosp/bionic/libc/system_properties/prop_area.cpp \
        aosp/bionic/libc/system_properties/prop_info.cpp \
        aosp/bionic/libc/system_properties/system_properties.cpp \
        aosp/system/core/base/strings.cpp \
        aosp/system/core/property_service/libpropertyinfoparser/property_info_parser.cpp \
        main.cpp \
        -static \
        -std=c++17 \
        -o "$bin_out/ih8sn"
fi

cp "$folder/scripts/updater-script" "$tmp_dir/$script_dir/updater-script"
cp "$folder/scripts/update-binary" "$tmp_dir/$script_dir/update-binary"

if [ "$arch" == "uninstall" ]; then
    cat "$folder/scripts/update-binary_uninstall" >>"$tmp_dir/$script_dir/update-binary"
    zip_name="ih8sn-uninstaller.zip"
    cp -r uninstall.sh "$tmp_dir/"
else
    cp -r system push.sh "$tmp_dir/"
    cat "$folder/scripts/update-binary_install" >>"$tmp_dir/$script_dir/update-binary"
fi

cd "$tmp_dir"
zip -q -r "$folder/$zip_name" *

rm -rf "$tmp_dir"
