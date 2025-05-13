
# ⚡ ASIOS™ Core
[![Sponsor](https://img.shields.io/github/sponsors/asi-os?label=Sponsor&logo=github)](https://github.com/sponsors/asi-os)

**ASIOS™ Core** is the heart of the OS—a custom Linux kernel and low-level runtime stack tuned for AI-native workloads. It provides:

- **🧠 AI-First Scheduler**  
  Deterministic, deep-learning-aware CPU scheduling for maximum throughput and fairness.  
- **🗺️ NUMA-Aware Memory Management**  
  Hugepage-enabled, topology-driven allocation optimized for AI training and inference.  
- **🚀 Zero-Copy GPU I/O**  
  GPUDirect Storage, RDMA, and low-latency DMA pipelines for GPU workloads.  
- **🔍 eBPF Observability & Self-Healing**  
  Kernel-space anomaly detection, telemetry, and automatic remediation.

---

## 🛠️ Quickstart

1. **Install prerequisites** (Ubuntu 24.04 HWE, x86_64 or ARM64):
   ```bash
   sudo apt update
   sudo apt install -y \
     build-essential flex bison libssl-dev libelf-dev bc \
     libncurses5-dev git python3-docutils curl \
     mbw rt-tests fio stress-ng jq


2. **Clone and prepare**:

   ```bash
   mkdir -p ~/projects && cd ~/projects
   git clone https://github.com/asi-os/asios-core.git
   cd asios-core

   # layout
   mkdir -p scripts/common scripts/x86_64 scripts/arm64 certs tests
   cp ~/build-asios-kernel.sh    scripts/common/
   cp ~/asios-config-overlay.sh  scripts/common/
   cp ~/build-deb-x86_64.sh      scripts/x86_64/build-deb.sh
   cp ~/build-deb-arm64.sh       scripts/arm64/build-deb.sh
   cp ~/certs/asios-signing.pub.pem certs/
   cp ~/tests/*.sh tests/
   ```

3. **Build host-only**:

   ```bash
   export USE_DISTRO_CONFIG=1 ASIOS_CLEANUP=0
   scripts/common/build-asios-kernel.sh --host-only
   ```

4. **Package & install**

   * **x86\_64**:

     ```bash
     scripts/x86_64/build-deb.sh
     cd output-debs
     sudo dpkg -i linux-headers-6.11.*_amd64.deb \
                  linux-image-6.11.*_amd64.deb \
                  linux-image-6.11.*-dbg_amd64.deb \
                  linux-libc-dev_*.deb
     sudo update-initramfs -c -k 6.11.*-asios
     sudo update-grub && sudo reboot
     ```
   * **ARM64**:

     ```bash
     scripts/arm64/build-deb.sh
     cd output-debs
     sudo dpkg -i linux-headers-6.11.*_arm64.deb \
                  linux-image-6.11.*_arm64.deb \
                  linux-image-6.11.*-dbg_arm64.deb \
                  linux-libc-dev_*.deb
     sudo update-initramfs -c -k 6.11.*-asios
     sudo update-grub && sudo reboot
     ```

---

## 🧪 Phase-1 Benchmarks

```bash
chmod +x tests/phase1_bench.sh
sudo tests/phase1_bench.sh \
  > tests/phase1/$(uname -m)/asios.json

# inspect results
jq . tests/phase1/$(uname -m)/asios.json
```

---

## ⚙️ CI (manual)

This workflow only runs when you click **Run workflow** in GitHub Actions.

---

## 📚 Next Steps

See the **ASIOS™ Docs** repository for in-depth guides:

- [ARCHITECTURE.md](https://github.com/asi-os/asios-docs/blob/main/ARCHITECTURE.md)  
- [ROADMAP.md](https://github.com/asi-os/asios-docs/blob/main/ROADMAP.md)  
- [CHANGELOG.md](https://github.com/asi-os/asios-docs/blob/main/CHANGELOG.md)  
- `asios-docs/ADR/` directory in the same repo

---

## 🤝 Contribute

Before your first PR:

1. Sign the [ICLA](https://github.com/asi-os/asios-legal/blob/main/ICLA.md) via CLA Assistant  
2. Add a DCO line to each commit:  
   ```bash
   git commit -s -m "Your description"
   ```
3. Follow the [CONTRIBUTING.md](https://github.com/asi-os/.github/blob/main/CONTRIBUTING.md) guide.

Happy hacking! 🚀

© 2025 KarLex AI, Inc. — see [Legal & Governance Portal](https://asios.ai/legal)
