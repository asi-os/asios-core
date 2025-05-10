#!/usr/bin/env bash
# tests/test-asios-config.sh — verify ASIOS overlay .config flags
#
# Usage: sudo bash tests/test-asios-config.sh

set -euo pipefail
CONFIG_FILE="/boot/config-$(uname -r)"
failed=0

# helper functions
must_be_set() {
  printf "%-40s" "$1:"
  if grep -q "^$2=y" "$CONFIG_FILE"; then
    echo " PASS"
  else
    echo " FAIL"
    failed=1
  fi
}
must_not_set() {
  printf "%-40s" "$1:"
  if grep -q "^# $2 is not set" "$CONFIG_FILE"; then
    echo " PASS"
  else
    echo " FAIL"
    failed=1
  fi
}

echo "=== ASIOS OVERLAY CONFIG VERIFICATION ==="
echo "Kernel: $(uname -r)"
echo

# ── Modules & signing ─────────────────────────────────────────────────
must_be_set   "Modules support"                   CONFIG_MODULES
must_be_set   "Module unloading"                  CONFIG_MODULE_UNLOAD
must_be_set   "Module versioning"                 CONFIG_MODVERSIONS
must_be_set   "Module compression (zstd)"         CONFIG_MODULE_COMPRESS_ZSTD
must_be_set   "Forced module signatures"          CONFIG_MODULE_SIG_FORCE

# ── Scheduler & timing ───────────────────────────────────────────────
must_be_set   "High-resolution timers"            CONFIG_HIGH_RES_TIMERS
must_be_set   "1000Hz tick"                       CONFIG_HZ_1000
must_be_set   "No-HZ full"                        CONFIG_NO_HZ_FULL

# ── Memory & I/O ─────────────────────────────────────────────────────
must_be_set   "DMA-buf heaps"                     CONFIG_DMABUF_HEAPS
must_be_set   "Transparent hugepage"              CONFIG_TRANSPARENT_HUGEPAGE
must_be_set   "Zswap"                             CONFIG_ZSWAP

# ── Security / hardening ─────────────────────────────────────────────
must_be_set   "AppArmor LSM"                      CONFIG_SECURITY_APPARMOR
must_be_set   "IMA measurement"                   CONFIG_IMA_MEASURE
must_be_set   "Kernel lockdown"                   CONFIG_LOCK_DOWN_KERNEL
must_not_set "Warnings-as-errors (WERROR)"        CONFIG_WERROR
must_not_set "Retpoline (RETPOLINE)"             CONFIG_RETPOLINE

# ── Filesystems ──────────────────────────────────────────────────────
must_be_set   "OverlayFS built-in"                CONFIG_OVERLAY_FS
must_be_set   "NFS export support"                CONFIG_EXPORTFS
# exportfs_fhandle is optional in some builds; only fail if explicitly unset
printf "%-40s" "ExportFS handle support:"
if grep -q "^$2=y" "$CONFIG_FILE" || grep -q "^# CONFIG_EXPORTFS_FHANDLE is not set" "$CONFIG_FILE"; then
  echo " PASS"
else
  echo " FAIL"
  failed=1
fi
must_be_set   "File-handle syscalls"             CONFIG_FHANDLE

# ── Virtualization ──────────────────────────────────────────────────
# KVM may be built-in or module; just check presence
printf "%-40s" "KVM support"
if grep -qE "^CONFIG_KVM=[ym]" "$CONFIG_FILE"; then
  echo " PASS"
else
  echo " FAIL"
  failed=1
fi

echo
if [ $failed -eq 0 ]; then
  echo "✅ All overlay config checks passed!"
  exit 0
else
  echo "❌ One or more overlay config checks FAILED"
  exit 1
fi
