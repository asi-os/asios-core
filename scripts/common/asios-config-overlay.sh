#!/usr/bin/env bash
# asios-config-overlay.sh — resilient .config overlay for ASIOS kernels
#
#  ▸ Call from build-asios-kernel.sh’s prepare_cfg() step.
#  ▸ Never aborts on unknown symbols; it just logs & continues.
#
#  2025-05-09  —  consolidated FS, FH, sysctl fixes + misc tidy-ups

set -euo pipefail
CONFIG_TOOL="scripts/config"

########################################################################
# helper: wrapper around scripts/config that tolerates absent symbols  #
########################################################################
cfg() {
    if ! $CONFIG_TOOL "$@" >/dev/null 2>&1; then
        echo "  ↳ skip $(printf '%s' "${*: -1}") (not in Kconfig)"
    fi
}

ARCH_ID="${1:-$(uname -m)}"      # arg from build script or host arch

########################################################################
# ── Source-level patches (Ubuntu HWE 6.11 quirks)                    #
########################################################################

# 1. AppArmor missing forward prototypes (LP: #206423)
if [[ -f security/apparmor/file.c ]] &&
   ! grep -q "__subj_label_is_cached" security/apparmor/file.c; then
    echo "↳ patching AppArmor prototypes" >&2
    sed -i '1i\
/* ASIOS overlay: add missing forward prototypes */\
bool __subj_label_is_cached(struct aa_label *subj_label);\
bool __file_is_delegated(struct aa_label *obj_label);\
' security/apparmor/file.c
fi

# 2. Suppress -Wempty-body warnings in af_unix.c
if [[ -f security/apparmor/af_unix.c ]]; then
    echo "↳ fixing empty-body ifs in af_unix.c" >&2
    sed -Ei 's/^( +)if \(([^)]+)\);\s*$/\1if (\2) { }/' security/apparmor/af_unix.c
fi

########################################################################
# ── Kconfig overlay — the meat                                        #
########################################################################
#
# Notes:
#   • ‘--enable’  sets =y   (built-in)      — use for core / boot-critical
#   • ‘--module’  sets =m   (loadable mod)  — use for drivers / optional
#   • ‘--disable’ drops the symbol entirely
#

if [[ "$ARCH_ID" == "x86_64" || "$ARCH_ID" == "aarch64" ]]; then

    # ── Modules & signature plumbing ──────────────────────────────────
    cfg --set-val CONFIG_SYSTEM_TRUSTED_KEYS       ""
    cfg --set-val CONFIG_SYSTEM_REVOCATION_KEYS    ""
    cfg --enable   CONFIG_MODULES CONFIG_MODULE_UNLOAD CONFIG_MODVERSIONS
    cfg --enable   CONFIG_MODULE_COMPRESS CONFIG_MODULE_COMPRESS_ZSTD
    cfg --enable   CONFIG_MODULE_SIG CONFIG_MODULE_SIG_ALL CONFIG_MODULE_SIG_FORCE

    # ── Core scheduler & timing ───────────────────────────────────────
    cfg --enable   CONFIG_HIGH_RES_TIMERS CONFIG_HZ_1000
    cfg --enable   CONFIG_NO_HZ_IDLE CONFIG_NO_HZ_FULL
    cfg --enable   CONFIG_SCHED_CORE CONFIG_SCHED_EXT CONFIG_SCHED_DEADLINE
    cfg --enable   CONFIG_CPUSETS CONFIG_NUMA CONFIG_SCHED_MC_PRIO CONFIG_RSEQ

    # ── Memory / I/O acceleration ─────────────────────────────────────
    cfg --enable   CONFIG_DMABUF_HEAPS CONFIG_DMABUF_MOVE_NOTIFY CONFIG_CMA
    cfg --enable   CONFIG_DMA_SHARED_BUFFER
    cfg --enable   CONFIG_TRANSPARENT_HUGEPAGE CONFIG_HUGETLB_PAGE
    cfg --enable   CONFIG_MEMCG CONFIG_SWAP_ACCOUNT CONFIG_NUMA_BALANCING
    cfg --enable   CONFIG_DAMON CONFIG_DAMON_LRU_SORT CONFIG_DAMON_SYSFS
    cfg --enable   CONFIG_ZSWAP CONFIG_ZSMALLOC CONFIG_Z3FOLD
    cfg --enable   CONFIG_NVME_CORE CONFIG_BLK_DEV_NVME CONFIG_NVME_TCP \
                   CONFIG_NVME_RDMA CONFIG_NVME_FC
    cfg --enable   CONFIG_SCSI CONFIG_PCIE CONFIG_PCIEAER CONFIG_PCI_P2PDMA

    # ── Security / hardening ──────────────────────────────────────────
    cfg --enable   CONFIG_TCG_TPM CONFIG_TCG_TIS
    cfg --enable   CONFIG_IMA CONFIG_IMA_MEASURE CONFIG_LOCK_DOWN_KERNEL
    cfg --enable   CONFIG_STACKPROTECTOR_STRONG
    cfg --enable   CONFIG_SECURITY_APPARMOR
    cfg --enable   CONFIG_BPF CONFIG_BPF_SYSCALL CONFIG_BPF_JIT CONFIG_BPF_JIT_HARDEN
    cfg --enable   CONFIG_BPF_LSM CONFIG_BPF_STREAM_PARSER CONFIG_BPF_PERF_EVENTS
    cfg --enable   CONFIG_DEBUG_INFO_BTF
    cfg --disable  CONFIG_RANDOM_TRUST_CPU
    cfg --enable   CONFIG_MAGIC_SYSRQ
    cfg --set-val  CONFIG_MAGIC_SYSRQ_DEFAULT_ENABLE "0x1"

    # ── Filesystem features (critical for ASIOS container & NFS stack) ─
    cfg --enable   CONFIG_OVERLAY_FS           # union-mounts built-in
    cfg --enable   CONFIG_EXPORTFS          # built-in exportfs support
    cfg --enable   CONFIG_EXPORTFS_FHANDLE   # name_to_handle_at(), open_by_handle_at()
    # Optional extra FS
    cfg --enable   CONFIG_BTRFS_FS CONFIG_NTFS3_FS CONFIG_EXFAT_FS
    cfg --enable   CONFIG_FHANDLE
    # ── Networking & drivers ──────────────────────────────────────────
    if [[ "$ARCH_ID" == "x86_64" ]]; then
        cfg --module CONFIG_E1000E CONFIG_R8169
    else
        cfg --module CONFIG_MLX5_CORE CONFIG_MLX5_INFINIBAND
    fi

    # ── Virtualisation & container plumbing ───────────────────────────
    cfg --enable CONFIG_KVM
    if [[ "$ARCH_ID" == "x86_64" ]]; then
        cfg --module CONFIG_KVM_INTEL CONFIG_KVM_AMD
        cfg --enable CONFIG_INTEL_IOMMU CONFIG_AMD_IOMMU
        cfg --enable CONFIG_AMD_PSTATE CONFIG_X86_INTEL_PSTATE
    else
        cfg --enable CONFIG_ARM_SMMU CONFIG_ARM_SMMU_V3_SVA
        # ARM-only AI/GPU/accel extras
        cfg --enable CONFIG_NTSYNC CONFIG_AMDXDNA CONFIG_HMM CONFIG_IVPU
    fi
    cfg --enable CONFIG_CGROUP_BPF CONFIG_CGROUP_PIDS CONFIG_CGROUP_FREEZER
    cfg --enable CONFIG_NAMESPACES CONFIG_VFIO CONFIG_VFIO_PCI CONFIG_IOMMUFD
    cfg --enable CONFIG_RDMA CONFIG_SDP CONFIG_KSM CONFIG_SECCOMP CONFIG_SECCOMP_FILTER
    cfg --enable CONFIG_MEMCG_SWAP

    # ── Power / firmware ──────────────────────────────────────────────
    cfg --enable CONFIG_ACPI CONFIG_EFI CONFIG_EFIVAR_FS CONFIG_ACPI_NUMA
    cfg --module CONFIG_CPU_FREQ_GOV_ONDEMAND CONFIG_CPU_FREQ_GOV_POWERSAVE \
                   CONFIG_CPU_FREQ_GOV_PERFORMANCE

    # ── Graphics / sound / misc drivers (modular) ─────────────────────
    cfg --module CONFIG_DRM CONFIG_DRM_KMS_HELPER CONFIG_DRM_I915 CONFIG_DRM_AMDGPU
    cfg --module CONFIG_FB_SIMPLE
    cfg --module CONFIG_SOUND CONFIG_SND
    cfg --enable CONFIG_IO_URING CONFIG_FSNOTIFY CONFIG_USB

    # ── CXL / experimental memory ─────────────────────────────────────
    cfg --module CONFIG_CXL_MEM CONFIG_CXL_PMEM

    # ── Low-latency profile ───────────────────────────────────────────
    cfg --enable CONFIG_PREEMPT CONFIG_PREEMPT_DYNAMIC

    # ── Debian packaging sanity ───────────────────────────────────────
    cfg --disable CONFIG_WERROR           # don’t fail build on warnings
    cfg --disable CONFIG_RETPOLINE        # Debian checkbin gripe workaround
fi
