# ResetZone Server Setup

## 1. Installation
Run these commands on your Linux server.

```bash
# 1. Install prerequisites
sudo apt update && sudo apt install git default-jdk -y

# 2. Clone repository
git clone https://github.com/Konijima/ResetZone.git
cd ResetZone

# 3. Setup 'pz_manager' command
# (Requires Python 3)
chmod +x System/ServerTools/pz_manager.py
sudo ln -sf "$PWD/System/ServerTools/pz_manager.py" /usr/local/bin/pz_manager

# 4. Open the Management Menu
pz_manager
# Use the interactive menu to:
# 1. [Install / Update Server]
# 2. [ResetZone Agent Manager] -> Build & Install Agent
```

## 2. Configuration
Use `pz_manager` -> **Mod Manager** to easily add the Workshop Item and Mod.

**Required:**
*   Workshop ID: `3639275134`
*   Mod ID: `ResetZone`

## 3. Usage
The `pz_manager` tool provides an interactive menu for all server tasks.

```bash
pz_manager
```

### Quick Commands (CLI)
You can also use these shortcuts for service control:
```bash
pz_manager start       # Start background service
pz_manager stop        # Stop service
pz_manager restart     # Restart service
pz_manager status      # Check service status
```

### Features (via Interactive Menu)
*   **Server Control:** View live logs, simple start/stop.
*   **Mod Manager:** Download Workshop items, toggle specific mods inside items easily.
*   **Agent Manager:** Auto-build and install the Java agent.
*   **Backup/Restore:** Manage server data backups.


---
### Repository Structure
* **Contents/**: Lua Mod source (upload this to Steam Workshop).
* **System/**: Server infrastructure (Java Agent & Manager Scripts).