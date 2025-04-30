
# ⚡ ASIOS™ Core

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

## 🛠️ Quickstart: Build & Install

### 1. Install Prerequisites

On Ubuntu 24.04 LTS HWE (x86_64 or ARM64):

```bash
sudo apt update
sudo apt install -y build-essential flex bison libssl-dev libelf-dev bc \
                    libncurses5-dev git python3-docutils
```

---

### 2. Clone the Repo

```bash
git clone https://github.com/asi-os/asios-core.git
cd asios-core
```

---

### 3. Configure

Auto-detects host architecture by default. To override:

```bash
ARCH=x86_64 ./scripts/configure.sh   # for x86_64
ARCH=arm64  ./scripts/configure.sh   # for ARM64
```

---

### 4. Build

```bash
make -j$(nproc)
```

---

### 5. Install & Reboot

```bash
sudo make modules_install install
sudo update-initramfs -u
sudo reboot
```

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
