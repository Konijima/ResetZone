# ResetZone Server Setup

## 1. Installation
Run these commands on your Linux server.

```bash
# 1. Install prerequisites
sudo apt update && sudo apt install git default-jdk -y

# 2. Clone repository
git clone https://github.com/konijima/ResetZone.git
cd ResetZone

# 3. Setup 'pz_manager' command
sudo cp System/ServerTools/pz_manager.sh /usr/local/bin/pz_manager
sudo chmod +x /usr/local/bin/pz_manager

# 4. Install Project Zomboid Server
pz_manager install
# (This creates the server at ~/pzserver and generated a systemd service)

# 5. Build and Install the ResetZone Java Agent
pz_manager setup-agent
# (Automatically finds source in ./System/JavaAgent or ~/ResetZone)
```

## 2. Configuration
Now configure the server to load the mod.

```bash
# Edit server configuration
pz_manager edit-config
```

**Add these lines:**
```ini
WorkshopItems=3639275134
Mods=ResetZone
```
*(Save: Ctrl+O, Enter. Open Sandbox vars: `pz_manager edit-sandbox`)*

## 3. Usage
You can manage the entire server using the `pz_manager` command.

### Server Control
```bash
pz_manager start       # Start the server (background service)
pz_manager stop        # Stop the server
pz_manager restart     # Restart the server
pz_manager status      # Check if server is running
pz_manager logs        # View live console logs (Ctrl+C to exit)
```

### Configuration & Modification
```bash
pz_manager edit-config   # Edit servertest.ini (Mods, Settings)
pz_manager edit-sandbox  # Edit Sandbox Options
pz_manager setup-agent   # Re-build and install the ResetZone Agent
```

### Maintenance
```bash
pz_manager update      # Update Project Zomboid via SteamCMD
pz_manager backup      # Create a backup of the 'Zomboid' data folder
pz_manager restore     # Restore data from a previous backup
```

---
### Repository Structure
* **Contents/**: Lua Mod source (upload this to Steam Workshop).
* **System/**: Server infrastructure (Java Agent & Manager Scripts).