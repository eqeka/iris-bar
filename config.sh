#!/usr/bin/env bash
# User-editable overrides for collector.sh. Leave a value empty (or delete
# the line) to let collector.sh auto-detect it instead.

# Network interface to measure throughput on, e.g. "wlp4s0", "eth0".
# Auto-detected from the default route if left empty.
NET_IFACE=""

# Backlight device name under /sys/class/backlight/. Auto-detected (first
# device found) if left empty. Set this explicitly on hybrid-GPU laptops
# where auto-detection might pick a decorative/non-functional entry
# (e.g. an Nvidia "nvidia_0" backlight stub next to the real amdgpu one).
BACKLIGHT_DEVICE=""

# Label `sensors` uses for CPU/GPU temperature on your machine. Several
# common ones are tried automatically in this order if left empty:
#   CPU: "CPU Temperature" (Lenovo Legion hwmon), "Tctl" (AMD), "Tdie" (AMD),
#        "Package id 0" (Intel coretemp)
#   GPU: "GPU Temperature" (Lenovo Legion hwmon), "edge" (amdgpu), "junction" (amdgpu)
# If your sensors output uses a different label, run `sensors` yourself and
# set these explicitly.
CPU_TEMP_LABEL=""
GPU_TEMP_LABEL=""

# GPU usage source: "nvidia" (via nvidia-smi), "amdgpu" (via sysfs
# gpu_busy_percent), or "" to auto-try nvidia first, then amdgpu, then give
# up and show "N/A".
GPU_MODE=""
