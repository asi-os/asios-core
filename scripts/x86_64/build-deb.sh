#!/usr/bin/env bash
# build-deb-x86_64.sh — Generate Debian packages for x86_64 after kernel build

set -euo pipefail
trap 'echo "❌ Build failed – see ${WORKDIR}" >&2' ERR

# Ensure the helper for debhelper-compat (=12) is present
sudo apt-get update
sudo apt-get install -y debhelper-compat

# Variables
ARCH="x86_64"
KVER=6.11
PKGREL=1
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS=$(nproc)
KDEB_PKGVERSION="${KVER}-asios${PKGREL}"
LOCALVERSION="-asios"

# Determine workdir: prefer x86_64_build/, fallback to kernel-build-
DEFAULT_DIR="${REPO_ROOT}/x86_64_build/kernel-build-${KVER}"
FALLBACK_DIR="${REPO_ROOT}/kernel-build-${KVER}"
if [ -d "${DEFAULT_DIR}" ]; then
  WORKDIR="${DEFAULT_DIR}"
elif [ -d "${FALLBACK_DIR}" ]; then
  WORKDIR="${FALLBACK_DIR}"
  echo "↳ Using ${WORKDIR} as kernel source for ${ARCH}"
else
  echo "Kernel source directory not found. Please ensure the kernel is compiled first."
  exit 1
fi

OUTPUT_DIR="${REPO_ROOT}/output-debs"
mkdir -p "${OUTPUT_DIR}"

# Build .deb packages
cd "${WORKDIR}"

echo "⭑ Refreshing config (olddefconfig) for ${ARCH}..."
make ARCH="${ARCH}" olddefconfig

echo "⭑ Building Debian packages for ${ARCH}..."
fakeroot make -j"${JOBS}" \
      ARCH="${ARCH}" bindeb-pkg \
      KDEB_PKGVERSION="${KDEB_PKGVERSION}" LOCALVERSION="${LOCALVERSION}" \
      DEB_BUILD_OPTIONS="parallel=${JOBS} nodoc"

# Move result
mv ../linux-*.deb "${OUTPUT_DIR}/"
echo -e "\n✅ Done – ${ARCH} packages at ${OUTPUT_DIR}"
