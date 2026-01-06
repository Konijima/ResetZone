# ResetZone Server Setup

This repository contains **ResetZone**, a map reset mod for Project Zomboid, and **PZ Manager**, a comprehensive server administration tool.

## 📥 Installation

Follow these steps to set up the server manager on a Linux machine (Ubuntu/Debian recommended).

```bash
# 1. Install prerequisites
sudo apt update && sudo apt install git default-jdk python3 curl tar lib32gcc-s1 -y

# 2. Clone repository
git clone https://github.com/Konijima/ResetZone.git
cd ResetZone

# 3. Setup 'pz_manager' command alias
chmod +x ServerTools/pz_manager.py
sudo ln -sf "$PWD/ServerTools/pz_manager.py" /usr/local/bin/pz_manager
```

## 🚀 Quick Start

Once installed, simply run the command to open the interactive dashboard:

```bash
pz_manager
```

Use the menu to:
1.  **Install / Update** the server files (via SteamCMD).
2.  **Mod Manager** to install the `ResetZone` mod (ID: `ResetZone`, Workshop: `3639275134`).
3.  **Service Control** to install the background service and start the server.

## 📚 Documentation

For full details on features, configuration, multi-instance setup, and automation, please read the [PZ Manager Documentation](ServerTools/README.md).
