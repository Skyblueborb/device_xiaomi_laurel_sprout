#! /vendor/bin/sh

# Copyright (c) 2012-2013, 2016-2019, The Linux Foundation. All rights reserved.
# Copyright (c) 2021, FrankFFFF @ No.912
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# * Redistributions of source code must retain the above copyright
#   notice, this list of conditions and the following disclaimer.
# * Redistributions in binary form must reproduce the above copyright
#   notice, this list of conditions and the following disclaimer in the
#   documentation and/or other materials provided with the distribution.
# * Neither the name of The Linux Foundation nor
#   the names of its contributors may be used to endorse or promote
#   products derived from this software without specific prior written
#   permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#
# WARN: THIS SCRIPT IS ONLY FOR XIAOMI MI A3(LAUREL_SPROUT) + NO.912 KERNEL.
# KANGING THIS SCRIPT WILL FUCK UP YOUR ROM AND KERNEL, EVEN ON SAME DEVICE.
#

# Read adj series and set adj threshold for PPR and ALMK.
# This is required since adj values change from framework to framework.
adj_series=`cat /sys/module/lowmemorykiller/parameters/adj`
adj_1="${adj_series#*,}"
set_almk_ppr_adj="${adj_1%%,*}"

# PPR and ALMK should not act on HOME adj and below.
# Normalized ADJ for HOME is 6. Hence multiply by 6
# ADJ score represented as INT in LMK params, actual score can be in decimal
# Hence add 6 considering a worst case of 0.9 conversion to INT (0.9*6).
# For uLMK + Memcg, this will be set as 6 since adj is zero.
set_almk_ppr_adj=$(((set_almk_ppr_adj * 6) + 6))
echo $set_almk_ppr_adj > /sys/module/lowmemorykiller/parameters/adj_max_shift

minfree_series=`cat /sys/module/lowmemorykiller/parameters/minfree`
minfree_1="${minfree_series#*,}" ; rem_minfree_1="${minfree_1%%,*}"
minfree_2="${minfree_1#*,}" ; rem_minfree_2="${minfree_2%%,*}"
minfree_3="${minfree_2#*,}" ; rem_minfree_3="${minfree_3%%,*}"
minfree_4="${minfree_3#*,}" ; rem_minfree_4="${minfree_4%%,*}"
minfree_5="${minfree_4#*,}"

vmpres_file_min=$((minfree_5 + (minfree_5 - rem_minfree_4)))
echo $vmpres_file_min > /sys/module/lowmemorykiller/parameters/vmpressure_file_min

# Enable adaptive LMK for all targets &
# use Google default LMK series for all 64-bit targets >=2GB.
echo 1 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper

#Set PPR parameters for all other targets.
echo $set_almk_ppr_adj > /sys/module/process_reclaim/parameters/min_score_adj
echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim
echo 50 > /sys/module/process_reclaim/parameters/pressure_min
echo 70 > /sys/module/process_reclaim/parameters/pressure_max
echo 30 > /sys/module/process_reclaim/parameters/swap_opt_eff
echo 512 > /sys/module/process_reclaim/parameters/per_swap_size

# Set swappiness to 100 for all targets
echo 100 > /proc/sys/vm/swappiness

# Disable wsf for all targets beacause we are using efk.
# wsf Range : 1..1000 So set to bare minimum value 1.
echo 1 > /proc/sys/vm/watermark_scale_factor

MemTotalStr=`cat /proc/meminfo | grep MemTotal`
MemTotal=${MemTotalStr:16:8}

let RamSizeGB="( $MemTotal / 1048576 ) + 1"
diskSizeUnit=M
let zRamSizeMB="( $RamSizeGB * 1024 ) / 2"

echo lz4 > /sys/block/zram0/comp_algorithm

if [ -f /sys/block/zram0/use_dedup ]; then
	echo 1 > /sys/block/zram0/use_dedup
fi
echo "$zRamSizeMB""$diskSizeUnit" > /sys/block/zram0/disksize

mkswap /dev/block/zram0
swapon /dev/block/zram0 -p 32758

echo 512 > /sys/block/mmcblk0/bdi/read_ahead_kb
echo 512 > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)
for dm in $dmpts; do
	echo 512 > $dm
done

# Apply settings for Trinket
# Set the default IRQ affinity to the silver cluster. When a
# CPU is isolated/hotplugged, the IRQ affinity is adjusted
# to one of the CPU from the default IRQ affinity mask.
echo f > /proc/irq/default_smp_affinity

# Disable Core control on silver
# echo 0 > /sys/devices/system/cpu/cpu0/core_ctl/enable
# Core control parameters on gold
echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
echo 30 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/task_thres

# Setting b.L scheduler parameters
echo 95 > /proc/sys/kernel/sched_upmigrate
echo 85 > /proc/sys/kernel/sched_downmigrate
echo 100 > /proc/sys/kernel/sched_group_upmigrate
echo 95 > /proc/sys/kernel/sched_group_downmigrate

echo 1000 > /dev/blkio/blkio.weight
echo 200 > /dev/blkio/background/blkio.weight
echo 2000 > /dev/blkio/blkio.group_idle
echo 0 > /dev/blkio/background/blkio.group_idle

# cpuset settings
echo "0-1" > /dev/cpuset/background/cpus
echo "0-3" > /dev/cpuset/system-background/cpus
echo "0-3,6-7" > /dev/cpuset/foreground/cpus
echo "0-7" > /dev/cpuset/top-app/cpus
echo "0-3" > /dev/cpuset/restricted/cpus

# configure governor settings for little cluster
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/down_rate_limit_us
echo 1420800 > /sys/devices/system/cpu/cpu0/cpufreq/schedutil/hispeed_freq
echo 1017600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

# configure governor settings for big cluster
echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/up_rate_limit_us
echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/down_rate_limit_us
echo 1536000 > /sys/devices/system/cpu/cpu4/cpufreq/schedutil/hispeed_freq
echo 1056000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq

echo 20 > /proc/sys/vm/stat_interval

# To override CAF's setup
setprop vendor.dcvs.prop 1

# colcoation v3 disabled
echo 0 > /proc/sys/kernel/sched_min_task_util_for_boost
echo 0 > /proc/sys/kernel/sched_min_task_util_for_colocation
echo 0 > /proc/sys/kernel/sched_little_cluster_coloc_fmin_khz

# Turn off scheduler boost at the end
echo 0 > /proc/sys/kernel/sched_boost

# Turn on sleep modes.
echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

setprop vendor.post_boot.parsed 1

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
	image_version="10:"
	image_version+=`getprop ro.build.id`
	image_version+=":"
	image_version+=`getprop ro.build.version.incremental`
	image_variant=`getprop ro.product.name`
	image_variant+="-"
	image_variant+=`getprop ro.build.type`
	oem_version=`getprop ro.build.version.codename`
	echo 10 > /sys/devices/soc0/select_image
	echo $image_version > /sys/devices/soc0/image_version
	echo $image_variant > /sys/devices/soc0/image_variant
	echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.vendor.console.silent.config`
case "$console_config" in
	"1")
		echo "Enable console config to $console_config"
		echo 0 > /proc/sys/kernel/printk
		;;
	*)
		echo "Enable console config to $console_config"
		;;
esac

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path

echo "UnityMain,libunity.so,libfb.so" > /proc/sys/kernel/sched_lib_name
