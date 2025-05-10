#!/usr/bin/env bash
# build-deb-arm64.sh — Generate Debian packages for ARM64 architecture after kernel build

set -euo pipefail
trap 'echo -e "\n❌ Build failed – see ${WORKDIR}" >&2' ERR

###############################################################################
# ── Variables and Setup ------------------------------------------------------
###############################################################################
ARCH="arm64"
TARGET_DIR="arm64_build"
KVER=6.11
WORKDIR="${TARGET_DIR}/kernel-build-${KVER}"
OUTPUT_DIR="${TARGET_DIR}/output-debs"
PKGREL=1
JOBS=$(nproc)
SIGNING_KEY="certs/asios-signing.pem"
OVERLAY_SCRIPT="asios-config-overlay.sh"
LOCALVERSION="-asios"
KDEB_PKGVERSION="${KVER}-asios${PKGREL}"

# Ensure you're in the correct directory with the compiled kernel
if [ ! -d "${WORKDIR}" ]; then
  echo "Kernel source directory not found. Please ensure the kernel is compiled first."
  exit 1
fi

# ── Install Dependencies -----------------------------------------------------
echo "⭑ Installing build pre-reqs for ARM64 ..."
sudo DEBIAN_FRONTEND=noninteractive apt-get -qq update
sudo DEBIAN_FRONTEND=noninteractive apt-get -yqq install \
  build-essential fakeroot bc flex bison libssl-dev libelf-dev dwarves \
  devscripts debhelper-compat liblz4-dev libzstd-dev libbz2-dev liblzma-dev \
  dpkg-dev crossbuild-essential-arm64 >/dev/null

###############################################################################
# ── Build Debian Package -----------------------------------------------------
###############################################################################
echo "⭑ Building Debian packages for ${ARCH} ..."
cd "${WORKDIR}"

# Make sure the kernel is configured and ready for building
make ARCH=arm64 olddefconfig

# Build the .deb packages
fakeroot make -j"$JOBS" \
        ARCH=arm64 bindeb-pkg \
        KDEB_PKGVERSION="$KDEB_PKGVERSION" \
        LOCALVERSION="$LOCALVERSION" \
        DEB_BUILD_OPTIONS="parallel=$JOBS nodoc"

###############################################################################
# ── Collect Output and Cleanup ----------------------------------------------
###############################################################################
mkdir -p "${OUTPUT_DIR}"
mv ../linux-*.deb "${OUTPUT_DIR}/"
echo -e "\n✅ Done – packages for ${ARCH} at $(realpath "${OUTPUT_DIR}")"
