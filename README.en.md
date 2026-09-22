<div align="center">

  <p>
    <a href="README.md">Español</a> | <b>English</b>
  </p>

  <img src="docs/assets/app_icon.png" width="128" height="128" alt="Compressor App Icon" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(0,0,0,0.3);" />

  # Compressor for macOS
  
  **The definitive native Image, Video, and PDF compressor for your Mac.**  
  *Local · Hardware Acceleration · Zero External Dependencies · Absolute Privacy*

  [![macOS 14+](https://img.shields.io/badge/macOS-Golden%20Gate%20%7C%20Sequoia%20%7C%20Sonoma-007AFF?style=flat-square&logo=apple&logoColor=white)](https://github.com/infoprojectstone/compressor)
  [![Swift 6.0](https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
  [![Architecture](https://img.shields.io/badge/Arch-Apple%20Silicon-000000?style=flat-square&logo=apple)](https://github.com/infoprojectstone/compressor)
  [![License](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](LICENSE)
  [![Website](https://img.shields.io/badge/Web-GitHub%20Pages-2563EB?style=flat-square&logo=githubpages&logoColor=white)](https://infoprojectstone.github.io/compressor/en.html)

  <br />

  <a href="https://github.com/infoprojectstone/compressor/releases">
    <img src="https://img.shields.io/badge/Download%20Installer-.DMG-2563eb?style=for-the-badge&logo=apple&logoColor=white" alt="Download DMG" />
  </a>
  <a href="https://infoprojectstone.github.io/compressor/en.html">
    <img src="https://img.shields.io/badge/Visit%20Website-Official%20Page-10b981?style=for-the-badge&logo=safari&logoColor=white" alt="Website" />
  </a>

  <br /><br />

  <img src="docs/assets/app_screenshot.png" width="920" alt="Compressor on macOS" />

</div>

<br />

## ✨ Key Features

* 🔒 **Local & Secure:** Your personal photos, confidential videos, and documents never touch the cloud or third-party servers. Zero telemetry and no internet connection required.
* ⚡ **GPU Acceleration:** Native video encoding and ultra-fast graphics processing using `AVFoundation`, `CoreGraphics`, and `ImageIO`, optimized for Apple Silicon chips.
* 🛡️ **Loss-Free Safety Guarantee:** Original files are never overwritten. If a compression fails to reduce file size, the system automatically discards the result and notifies you with the status *"No improvement"*.
* 📁 **Finder Integration:** Compress files or entire folders with a single right-click from Finder's context menu without opening the app beforehand.
* 🎯 **Dual Operation Modes:**
  * **Quality Mode:** Choose between *High quality*, *Balanced*, or *Small size*.
  * **Target Size Mode:** Specify the exact desired maximum size in megabytes (MB) (ideal for email, WhatsApp, or platforms with strict upload limits).

---

## 🗂️ The Three Engines in Detail

### 📸 1. Images
* **Supported formats:** JPG, PNG, WebP, HEIC (iPhone photos), and HEIF.
* **Smart preservation:** Preserves alpha transparency and original color profiles.
* **Typical savings:** From **-60% to -95%** with no noticeable visual loss.

### 🎬 2. Video
* **Supported formats:** MP4, MOV, and M4V.
* **Technology:** Native pipeline using `AVAssetReader` + `AVAssetWriter` with adaptive two-pass bitrate control and high-fidelity AAC stereo audio.
* **Resolutions:** Auto (max 1080p), 720p, 540p, or original resolution.
* **Typical savings:** From **-50% to -85%**.

### 📄 3. PDF Documents (`SafePDFCompressor`)
* **Hybrid two-tier native engine:**
  * **Tier 1 (Vectorial with `QuartzFilter`):** Optimizes and recompresses embedded photos and imagery, **preserving full sharpness for typography, hyperlinks, and selectable text**.
  * **Tier 2 (Intelligent Adaptive Rasterization):** Specifically tailored for scanned documents (pages that are pure images). Computes a per-page byte budget to ensure the output file is always lighter than the original.
* **Typical savings:** From **-50% to -95%**.

---

## 🖱️ Finder Integration (Quick Action)

Compress any file or folder directly from Finder:

1. Open **Settings** inside Compressor (`Cmd` + `,`).
2. Go to the **Finder Integration** section and click **"Install Quick Action"**.
3. Right-click any image, video, or PDF in Finder and select:
   * **Quick Actions > Compress with Compressor** (or from the Services menu).
   * The app will launch instantly, switch to the appropriate tab, and queue the selected files for processing.

---

## 🚀 Installation & Security (Gatekeeper)

Since this is an independent open-source application distributed without Apple's paid corporate developer certificate:

1. Download [`Compressor-1.2.dmg`](https://github.com/infoprojectstone/compressor/releases) and open it.
2. Drag **Compressor** into your **Applications** folder.
3. The first time you launch the app, if macOS displays the warning *"cannot be opened because Apple cannot check it for malicious software"*:
   * **Right-click** (or `Control` + click) Compressor in your Applications folder and click **Open**.
   * Or go to **System Settings > Privacy & Security** and click **"Open Anyway"**.

---

## 🛠️ Build & Development

Requirements: macOS 13.0 or later, Xcode Command Line Tools (`xcode-select --install`).

* **Run full test suite:**
  ```bash
  zsh scripts/run-tests.sh
  ```

* **Build Release app and package .ZIP:**
  ```bash
  zsh scripts/build-app.sh
  ```

* **Create DMG installer:**
  ```bash
  zsh scripts/create-dmg.sh
  ```
