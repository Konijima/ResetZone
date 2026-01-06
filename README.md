# ResetZone Server Setup

## 1. Installation
Run these commands on your Linux server.

```bash
# 1. Install prerequisites
sudo apt update && sudo apt install git default-jdk python3 -y

# 2. Clone repository
git clone https://github.com/Konijima/ResetZone.git
cd ResetZone

# 3. Setup 'pz_manager' command
# (Requires Python 3)
chmod +x ServerTools/pz_manager.py
sudo ln -sf "$PWD/ServerTools/pz_manager.py" /usr/local/bin/pz_manager

# 4. Open the Management Menu
pz_manager
# Use the interactive menu to:
# 1. [Install / Update Server]
# 2. [Configuration] -> Run setup
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
*   **Configuration:** Manage memory, restart schedule, backups, and **server name / save files**.
*   **Mod Manager:** Add/Remove Workshop items and Mods directly.
*   **Mod Manager:** Download Workshop items, toggle specific mods inside items easily.
*   **Backup/Restore:** Manage server data backups.

## 4. Scheduler & Automation
The **Scheduler** is a background service that automates maintenance tasks.

**It handles:**
1.  **Auto-Restarts:** Based on your configured schedule (default: 0, 6, 12, 18 hours).
2.  **RCON Broadcasts:** Warns players 60, 30, 10, 5, and 1 minute before restart.
3.  **Auto-Backup:** Creates a backup of the server saves before restarting.
4.  **Reset Zones:** Cleans up map chunks marked for reset by the mod.

**To Enable:**
1.  Run `pz_manager` -> **Server Control**.
2.  Select **Install Scheduler (Auto-Restart)**.
3.  This creates a systemd service (`pzserver-scheduler`) that runs in the background.

---
### Repository Structure
* **Contents/**: Lua Mod source (upload this to Steam Workshop).
* **ServerTools/**: Python Manager Scripts (`pz_manager`).
