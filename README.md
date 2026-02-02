# 🌑 Deimos

**Secure. Private. Authenticated.** *A hardened desktop gaming image based on [Bazzite](https://bazzite.gg).*

---

## 🌌 The Vision
**Deimos** is a custom OS image built directly on the **Bazzite** OCI foundation. While Bazzite provides the ultimate gaming experience—including curated drivers and specialized kernels—Deimos extends this by adding a rigorous **Security and Privacy** layer.

Named after the smaller, outer moon of Mars, Deimos acts as an impenetrable sentinel guarding your system integrity.

---

## 🛡️ The "Aegis" Security Layer
The defining feature of Deimos is the move toward hardware-backed trust. We have integrated specialized tooling to bridge the gap between high-performance gaming and enterprise-grade boot security.

* **Hardware-Backed UKI Signing:** Deimos includes custom logic to sign Unified Kernel Images (UKI) using a **Yubikey** (via `sbctl` and `go-piv`).
* **Physical Presence Verification:** System updates that modify the bootloader require a physical touch on your Yubikey. No remote actor can modify your boot chain without your physical consent.
* **Secure Boot Integration:** Designed for users who enroll their own keys (PK/KEK/db). Deimos automates the signing of the kernel and bootloader during the `rpm-ostree` update cycle.
* **Privacy Hardening:** In addition to Bazzite's base, Deimos implements stricter Flatpak permissions and zero-telemetry configurations.

---

## 🎮 Gaming Performance
Deimos inherits the performance DNA of **Bazzite**. By basing our image on theirs, we provide:
* **Proprietary Drivers:** Pre-installed and configured NVIDIA/Mesa drivers.
* **Performance Kernels:** Patched for high-frequency gaming and low process latency.
* **Bazzite Tooling:** Inherits the vast hardware compatibility and gaming stack provided by the upstream Bazzite image.

> **Note:** Deimos is optimized for Desktop and Laptop users. Unlike base Bazzite, it does not default to the Steam Deck Game Mode UI.

---

## 🚀 Installation

### 1. Rebase to Deimos
If you are already on a uBlue or Bazzite-based system, you can rebase directly:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/YOUR_GITHUB_USERNAME/deimos:latest
```

### 2. Physical Signing Setup
Deimos expects a Yubikey for its automated signing services. To initialize the hardware bridge:

1.  Ensure your UEFI is in **Setup Mode**.
2.  Run the Deimos setup utility:
    ```bash
    /usr/bin/deimos-init-aegis
    ```
3.  Enter your PIN and **Touch your Yubikey** when prompted.

---

## 🛠️ Technical Implementation
Deimos utilizes a unique background service architecture to handle Secure Boot:

1.  **Detection:** A `systemd.path` unit monitors for kernel updates.
2.  **Verification:** The service ensures the Yubikey is inserted before proceeding.
3.  **Secure Bridge:** It uses `systemd-ask-password` to prompt for your PIN via a secure desktop popup, then pipes it directly to the signing tool to avoid environment leaks.

---

## 🤝 Credits
* **Foundation:** [Bazzite](https://github.com/ublue-os/bazzite) (uBlue-OS).
* **Security Tools:** [sbctl](https://github.com/Foxboron/sbctl).
* **Identity:** Deimos is an independent project and is not affiliated with the official Bazzite or Fedora teams.
