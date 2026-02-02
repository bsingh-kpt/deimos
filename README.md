# 🌑 Deimos OS

**Verified. Private. Authenticated.** *A Bazzite-based gaming OS featuring a hardware-verified boot chain.*

---

## 🌌 The Vision
**Deimos OS** is named after the outer moon of Mars—a celestial sentinel guarding its planet. While typical security-focused distributions often sacrifice usability to minimize attack surface, Deimos OS takes a different path. 

Our goal is to provide a high-performance gaming environment where **System Integrity** is paramount. We don't just "shield" the OS; we provide the cryptographic infrastructure to prove that your kernel, drivers, and bootloader are authentic and untampered.

---

## 🛡️ The Deimos Integrity Suite
This suite moves the "Chain of Trust" from software-only checks to physical hardware verification.



* **Hardware-Backed UKI Signing:** Custom logic to sign Unified Kernel Images (UKI) using an **RSA** key pair and a physical **Yubikey**.
* **Mandatory Physical Presence:** System updates that modify the bootloader require a physical touch on your Yubikey. This prevents remote actors from performing "silent" updates to your boot chain.
* **Authenticated Boot:** Built for users who enroll their own Secure Boot keys (PK/KEK/db). Deimos OS automates the signing process during the `rpm-ostree` update cycle to maintain a continuous chain of trust.
* **Integrity Enforcement:** Enhanced Flatpak permission overrides and zero-telemetry defaults ensure your system remains under your exclusive control.

---

## 🎮 High-Performance Gaming
Deimos OS maintains the full gaming DNA of **Bazzite** while enhancing the underlying security model:

* **Open-Source NVIDIA Drivers:** Leverages NVIDIA's **open-source kernel modules**, allowing for seamless cryptographic signing and better integration with immutable system updates.
* **Performance Kernels:** Pre-patched for high-frequency gaming and low-latency process scheduling.
* **The Bazzite Stack:** Includes the full suite of gaming tools (Steam, Lutris, Wayland optimizations) without the handheld-specific UI defaults.


---

## 🚀 Installation

### 1. Establish the Chain of Trust
To ensure the integrity of the image before installation, you must first trust the Deimos OS public key. Run the following command to download and trust the signature:

```bash
curl -Lo /etc/pki/containers/deimos.pub https://raw.githubusercontent.com/bsingh-kpt/deimos/main/cosign.pub
```

### 2. Rebase to Deimos OS (Verified)
With the key in place, perform a verified rebase. This ensures that `rpm-ostree` will only pull the image if the signature matches your public key:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/bsingh-kpt/deimos:latest
```

### 3. Initializing the Integrity Suite
To enroll your hardware keys and establish your local chain of trust:

1.  Ensure your UEFI is in **Setup Mode**.
2.  Run the Deimos setup utility:
    ```bash
    /usr/bin/deimos-init-integrity
    ```
3.  Enter your PIN and **Touch your Yubikey** when the LED flashes.

---

## 🛠️ Technical Implementation
Deimos OS utilizes a specialized background architecture to handle Secure Boot automation:

1.  **Detection:** A `systemd.path` unit monitors for new kernel deployments.
2.  **Hardware Verification:** The service verifies the Yubikey is physically connected before initiating the signing process.
3.  **Secure Bridge:** Uses `systemd-ask-password` for secure PIN entry, preventing sensitive credentials from appearing in the system process tree.

---

## 🤝 Credits & Identity
* **Foundation:** [Bazzite](https://github.com/ublue-os/bazzite) (uBlue-OS).
* **Security Tools:** [sbctl](https://github.com/Foxboron/sbctl).
* **Identity:** Deimos OS is an independent project and is not affiliated with Valve, NVIDIA, Fedora, or the official uBlue team.
