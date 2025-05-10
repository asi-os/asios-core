#!/usr/bin/env bash
# build-asios-kernel.sh — compile Ubuntu HWE 6.11 kernels for ASIOS into separate arch trees
set -euo pipefail
trap 'echo -e "\n❌ Build failed – see ${BUILD_DIR}" >&2' ERR

###############################################################################
# ── CLI flag -----------------------------------------------------------------
###############################################################################
HOST_ONLY=0
[[ ${1:-} == --host-only ]] && HOST_ONLY=1 && shift

###############################################################################
# ── Tunables -----------------------------------------------------------------
###############################################################################
KVER=6.11
UBUNTU_HWE_REPO="https://git.launchpad.net/ubuntu/+source/linux-hwe-${KVER}"
BRANCH="ubuntu/noble-updates"
JOBS=$(nproc)
SIGNING_KEY="certs/asios-signing.pem"
OVERLAY_SCRIPT="asios-config-overlay.sh"
USE_DISTRO_CONFIG="${USE_DISTRO_CONFIG:-1}"    # default to using stock HWE .config
ASIOS_CLEANUP="${ASIOS_CLEANUP:-1}"

###############################################################################
# ── Paths --------------------------------------------------------------------
###############################################################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}"

###############################################################################
# ── Pre-flight ---------------------------------------------------------------
###############################################################################
for t in git make; do
  command -v "$t" >/dev/null || { echo "Missing tool: $t"; exit 1; }
done
[[ -f "${REPO_ROOT}/${SIGNING_KEY}" ]] || { echo "Missing ${SIGNING_KEY}"; exit 1; }

echo "⭑ Installing build pre-reqs (quiet)…"
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update
sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq install \
    build-essential bc flex bison libssl-dev libelf-dev dwarves \
    liblz4-dev libzstd-dev libbz2-dev liblzma-dev \
    crossbuild-essential-arm64 crossbuild-essential-amd64 >/dev/null

###############################################################################
# ── Helpers ------------------------------------------------------------------
###############################################################################
canon_arch() { [[ $1 == aarch64 ]] && echo arm64 || echo "$1"; }

prepare_cfg() {
  local arch="$1" dir="$2"
  pushd "$dir" >/dev/null
  local carch=$(canon_arch "$arch")

  echo -e "\n⭑ Preparing .config for ${carch}"
  if [[ $USE_DISTRO_CONFIG -eq 1 && $arch == $(uname -m) ]]; then
    # try /proc/config.gz first
    if [[ -f /proc/config.gz ]]; then
      zcat /proc/config.gz > .config
    elif [[ -f /boot/config-$(uname -r) ]]; then
      # Ubuntu's config is plain text
      cp /boot/config-$(uname -r) .config
    else
      echo "⚠️  No distro config found; falling back to defconfig"
      make mrproper
      make ARCH="$carch" defconfig
      popd >/dev/null
      return
    fi
    make ARCH="$carch" olddefconfig
  else
    make mrproper
    make ARCH="$carch" defconfig
  fi

  # apply only our overlay tweaks
  bash "${REPO_ROOT}/${OVERLAY_SCRIPT}" "$arch"

  # install signing key info
  ./scripts/config --set-str CONFIG_SYSTEM_TRUSTED_KEYS "${REPO_ROOT}/${SIGNING_KEY}"
  ./scripts/config --set-val CONFIG_SYSTEM_REVOCATION_KEYS ""

  # disable retpoline so Debian packaging checkbin passes
  ./scripts/config --disable CONFIG_RETPOLINE

  # drop WERROR so stray warnings don’t break build
  ./scripts/config --disable CONFIG_WERROR

  # re‑finalize
  make -s ARCH="$carch" olddefconfig
  popd >/dev/null
}

build_kernel() {
  local arch="$1" cross="$2" dir="$3"
  local carch=$(canon_arch "$arch")
  echo -e "\n⭑ Compiling kernel for ${carch}"
  make -C "$dir" ARCH="$carch" CROSS_COMPILE="$cross" -j"$JOBS"
}

do_one_arch() {
  local arch="$1" cross="$2"
  local carch=$(canon_arch "$arch")
  BUILD_DIR="${REPO_ROOT}/${carch}_build/kernel-build-${KVER}"

  echo "⭑ Setting up build tree for ${carch}: ${BUILD_DIR}"
  rm -rf "$BUILD_DIR"
  mkdir -p "$(dirname "$BUILD_DIR")"

  echo "⭑ Cloning Ubuntu HWE ${KVER} for ${carch}…"
  git clone --depth=1 -b "$BRANCH" "$UBUNTU_HWE_REPO" "$BUILD_DIR"

  prepare_cfg "$arch" "$BUILD_DIR"
  build_kernel   "$arch" "$cross" "$BUILD_DIR"

  if [[ ${ASIOS_BUILD_DBG:-0} -eq 1 ]]; then
    echo "  ↳ Debug flavour for ${carch}"
    pushd "$BUILD_DIR" >/dev/null
    ./scripts/config --enable CONFIG_DEBUG_INFO CONFIG_DEBUG_FS CONFIG_KPROBES CONFIG_PAGE_POISONING
    yes "" | make ARCH="$carch" olddefconfig
    popd >/dev/null
    build_kernel "$arch" "$cross" "$BUILD_DIR"
  fi

  echo "✅ ${carch} build complete: ${BUILD_DIR}"
  if (( ASIOS_CLEANUP )); then
    echo "🧹 Removing ${BUILD_DIR}"
    rm -rf "$BUILD_DIR"
  else
    echo "📁 Build tree left at ${BUILD_DIR}"
  fi
}

###############################################################################
# ── Build matrix -------------------------------------------------------------
###############################################################################
export KBUILD_BUILD_USER="asios-ci"
export KBUILD_BUILD_HOST="$(hostname -s)"

HOST_ARCH="$(uname -m)"
TARGETS=("$HOST_ARCH")
if (( HOST_ONLY == 0 )); then
  [[ $HOST_ARCH == x86_64 ]]  && TARGETS+=(aarch64)
  [[ $HOST_ARCH == aarch64 ]] && TARGETS+=(x86_64)
fi

for arch in "${TARGETS[@]}"; do
  if [[ $arch == $HOST_ARCH ]]; then
    cross=""
  else
    cross=$([[ $arch == aarch64 ]] && echo aarch64-linux-gnu- || echo x86_64-linux-gnu-)
  fi
  do_one_arch "$arch" "$cross"
done

echo -e "\n✅ All kernels built."
