# Big DockLocker 

<p align="left">
  <img src="Assets/AppIcon.png" alt="Big DockLocker Logo" width="128">
</p>

**Big DockLocker** is a lightweight macOS utility designed to solve a long-standing frustration for multi-monitor users: the "jumping Dock." It allows you to pin the macOS Dock to a specific display and prevents it from moving to other screens, even when performing bottom-edge gestures.

**v1.5.0 Signature Edition** features a refined visual theme and professional identity.

[![Swift Version](https://img.shields.io/badge/Swift-6.0-F05138.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platforms-macOS_13+-lightgrey.svg)](https://developer.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![semantic-release](https://img.shields.io/badge/%20%20%F0%9F%93%A6%F0%9F%9A%80-semantic--release-e10079.svg)](https://github.com/semantic-release/semantic-release)

---

## 📋 Table of Contents
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Installation](#-installation-recommended)
- [Usage](#-usage)
- [Troubleshooting](#-troubleshooting)
- [Development](#-development)
- [Contributing](#-contributing)
- [License](#-license)
- [Acknowledgments](#-acknowledgments)

---

## 🚀 Features

- **Persistent Dock Pinning:** Choose which monitor should hold the Dock and keep it there.
- **Gesture Blocking:** Actively prevents the mouse from triggering the Dock relocation gesture on non-primary displays.
- **Native SwiftUI Dashboard:** Simple interface to manage your monitor setup and engine status.
- **Menu Bar Integration:** Runs as a resident utility in the system tray.
- **Launch at Login:** Option to start automatically when you log into your Mac.
- **Automated Releases:** Continuous delivery via `semantic-release` and GitHub Actions.

---

## 📸 Screenshots

<p align="center">
  <img src="Assets/dashboard.png?v=2" alt="Big DockLocker Dashboard" width="60%">
</p>

---

## 🚀 Installation (Recommended)

Follow these three steps to get **Big DockLocker** running on your Mac.

### 1. Download & Install
1.  Go to the [Releases](https://github.com/danielvm-git/bigdocklocker/releases) page and download the installer for your Mac type:
    *   **Apple Silicon (M1/M2/M3):** Download `BigDockLocker-apple-silicon-mac.dmg`.
    *   **Intel Mac:** Download `BigDockLocker-intel-mac.dmg`.
2.  Open the `.dmg` file and drag the **Big DockLocker** icon into your **Applications** folder.

### 2. Allow the App (Security & Privacy)
Because Big DockLocker is an open-source tool and not currently sold through the Mac App Store, macOS may show a warning: *"Apple could not verify 'Big DockLocker' is free of malware."*

**To allow the app to run:**
1.  Open the **Applications** folder and double-click **Big DockLocker**.
2.  When the warning appears, click **OK** (the app will stay blocked for a moment).
3.  Open **System Settings** → **Privacy & Security**.
4.  Scroll down to the "Security" section. You will see a message: *"Big DockLocker was blocked to protect your Mac."*
5.  Click **Open Anyway**, enter your password, and click **Open** on the final confirmation.

> [!TIP]
> **Power User Shortcut:** You can skip the "System Settings" steps by running this command in your Terminal:
> `xattr -dr com.apple.quarantine /Applications/BigDockLocker.app`

### 3. Grant Permissions
Big DockLocker needs **Accessibility Permissions** to detect when your mouse is near the edge of the screen so it can lock the Dock in place.

1.  Open **System Settings** → **Privacy & Security** → **Accessibility**.
2.  Click the **+** button (or drag **Big DockLocker** from your Applications folder into the list).
3.  Ensure the switch next to **Big DockLocker** is turned **ON**.

---

## 💡 Usage

1.  Launch **Big DockLocker** from your Applications folder.
2.  Look for the **Lock icon** in your top Menu Bar.
3.  Select **Dashboard** to choose which monitor should hold your Dock.
4.  Click **Start Engine** to activate the protection.

---

## 🛠 Troubleshooting

### "Apple could not verify..." or "Unidentified Developer"
This is the standard macOS security check for apps downloaded outside the App Store. Following **Step 2** in the Installation guide above will resolve this permanently for your machine.

### Dock is still jumping?
Ensure that the Accessibility toggle in System Settings is active. If it is already on, try toggling it **OFF** and then **ON** again to refresh the system trust.

---

## 👨‍💻 Development

### Prerequisites
*   macOS 13 (Ventura) or newer.
*   **Xcode 15+** or the latest Swift command-line tools.

### Build from Source
If you prefer to build the binary yourself:

```bash
git clone https://github.com/danielvm-git/bigdocklocker.git
cd bigdocklocker
./run.sh
```

### Technical Architecture
Big DockLocker is built with **Swift 6** and **SwiftUI**, utilizing low-level macOS APIs:

- **Core Graphics (`CGEventTap`):** Intercepts and modifies mouse movement events at the system level.
- **Accessibility API (`AXUIElement`):** Required for the event tap to function as a trusted process.
- **ServiceManagement (`SMAppService`):** Handles the modern macOS "Launch at Login" registration.
- **CoreGraphics (`CGDirectDisplayID`):** Manages multi-monitor identification and coordinate mapping.

### Testing
Run the automated test suite to verify coordinate logic and manager interfaces:
```bash
swift test
```

---

## 🤝 Contributing

Contributions are what make the open-source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

### Automated Releases & Commit Messages
This project uses **Semantic Release** to automate versioning and changelog generation. Because of this, **your commit messages must follow [Conventional Commits](https://www.conventionalcommits.org/)**.

The type of commit determines how the version number is bumped:
- **`fix:`** triggers a **patch** release (e.g., 1.0.0 -> 1.0.1).
- **`feat:`** triggers a **minor** release (e.g., 1.0.0 -> 1.1.0).
- **`BREAKING CHANGE:`** (in the footer) triggers a **major** release (e.g., 1.0.0 -> 2.0.0).

---

### Step-by-Step Guide
1. **Fork** the Project.
2. **Create** your Feature Branch (`git checkout -b feat/AmazingFeature`).
3. **Commit** your Changes using a conventional message (e.g., `git commit -m 'feat: Add some AmazingFeature'`).
4. **Push** to the Branch (`git push origin feat/AmazingFeature`).
5. **Open** a Pull Request.

---

## 📜 License

Distributed under the MIT License. See [LICENSE](LICENSE) for more information.

---

## 🌟 Acknowledgments

*   Concept inspired by the excellent [Big DockLocker Pro](https://docklockpro.com/).
*   Developed using the [bigpowers](https://github.com/danielvm-git/bigpowers) AI orchestration methodology.