#!/usr/bin/env bash
# tests/test-asios-config.sh — verify ASIOS overlay .config flags
#
# Usage: sudo bash tests/test-asios-config.sh

set -euo pipefail
CONFIG_FILE="/boot/config-$(uname -r)"
failed=0

# functions to test boolean flags
test_set() {
  desc="$1"; symbol="$2"
  printf "%-35s" "$desc:"
  if grep -q "^${symbol}=y" "$CONFIG_FILE"; then
    echo " PASS"
  else
    echo " FAIL"
    failed=1
  fi
}

test_not_set() {
  desc="$1"; symbol="$2"
  printf "%-35s" "$desc:"
  if grep -q "^# ${symbol} is not set" "$CONFIG_FILE"; then
    echo " PASS"
  else
    echo " FAIL"
    failed=1
  fi
}

test_kvm() {
  desc="$1"
  printf "%-35s" "$desc:"
  if grep -qE "^CONFIG_KVM=[ym]" "$CONFIG_FILE"; then
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
test_set     "Modules support"                CONFIG_MODULES
test_set     "Module unload support"          CONFIG_MODULE_UNLOAD
test_set     "Module versioning support"      CONFIG_MODVERSIONS
test_set     "Module zstd compression"        CONFIG_MODULE_COMPRESS_ZSTD
test_not_set "Forced warnings-as-errors"      CONFIG_WERROR

# ── Scheduler & timing ───────────────────────────────────────────────
test_set     "High-resolution timers"         CONFIG_HIGH_RES_TIMERS
test_set     "1000Hz tick rate"               CONFIG_HZ_1000
test_set     "No-HZ full (tickless)"          CONFIG_NO_HZ_FULL

# ── Memory & I/O acceleration ────────────────────────────────────────
test_set     "DMA-buf heaps"                  CONFIG_DMABUF_HEAPS
test_set     "Transparent hugepage"           CONFIG_TRANSPARENT_HUGEPAGE
test_set     "Zswap support"                  CONFIG_ZSWAP

# ── Security / hardening ─────────────────────────────────────────────
test_set     "AppArmor LSM"                   CONFIG_SECURITY_APPARMOR
test_set     "IMA measurement"                CONFIG_IMA_MEASURE
test_set     "Kernel lockdown"                CONFIG_LOCK_DOWN_KERNEL
test_not_set "Retpoline disabled"             CONFIG_RETPOLINE

# ── Filesystems ──────────────────────────────────────────────────────
test_set     "OverlayFS built-in"             CONFIG_OVERLAY_FS
test_set     "NFS export support"             CONFIG_EXPORTFS
test_set     "ExportFS block operations"      CONFIG_EXPORTFS_FHANDLE
test_set     "File-handle syscalls"           CONFIG_FHANDLE

# ── Virtualization ──────────────────────────────────────────────────
test_kvm     "KVM support (built-in or module)"

echo
if [ $failed -eq 0 ]; then
  echo "✅ All overlay config checks passed!"
  exit 0
else
  echo "❌ One or more overlay config checks FAILED"
  exit 1
fi
