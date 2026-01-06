#!/bin/bash
set -e

# Project Zomboid Server Manager (Steam Enabled)
# Handles Installation, Updates, Backups, and Service Control for Build 42 (Unstable).

# --- Configuration ---
APP_ID=380870
BRANCH="unstable" # Use "unstable" for Build 42
INSTALL_DIR="$HOME/pzserver"
STEAMCMD_DIR="$HOME/steamcmd"
BACKUP_DIR="$HOME/pzbackups"
SERVICE_NAME="pzserver"
ZOMBOID_DATA_DIR="$INSTALL_DIR/Zomboid" # Self-contained data directory
SERVER_MEMORY="2g" # Memory allocation (e.g., 2g, 4g, 8g)

# --- Helper Functions ---

check_deps() {
    echo "Checking dependencies..."
    if ! command -v curl &> /dev/null || ! command -v tar &> /dev/null || ! command -v python3 &> /dev/null; then
        echo "Installing dependencies (curl, tar, python3)..."
        if [ "$EUID" -ne 0 ] && command -v sudo &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y lib32gcc-s1 curl wget tar python3
        elif [ "$EUID" -eq 0 ]; then
            apt-get update && apt-get install -y lib32gcc-s1 curl wget tar python3
        else
            echo "Error: Missing dependencies and cannot run apt-get (no sudo)."
            exit 1
        fi
    fi
}

install_steamcmd() {
    if [ ! -f "$STEAMCMD_DIR/steamcmd.sh" ]; then
        echo "Installing SteamCMD..."
        mkdir -p "$STEAMCMD_DIR"
        cd "$STEAMCMD_DIR"
        curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    fi
}

configure_server() {
    echo "Configuring Server (Memory: $SERVER_MEMORY, Steam: Enabled)..."
    
    # 1. Create start-server-steam.sh (Wrapper)
    SRC_SCRIPT="$INSTALL_DIR/start-server.sh"
    DST_SCRIPT="$INSTALL_DIR/start-server-steam.sh"
    
    if [ -f "$SRC_SCRIPT" ]; then
        cp "$SRC_SCRIPT" "$DST_SCRIPT"
        chmod +x "$DST_SCRIPT"
    else
        echo "Warning: $SRC_SCRIPT not found."
    fi

    # 2. Configure ProjectZomboid64.json
    JSON_FILE="$INSTALL_DIR/ProjectZomboid64.json"
    if [ -f "$JSON_FILE" ]; then
        # Update Memory (Replace existing -Xmx value)
        sed -i "s/-Xmx[0-9]*[mg]/-Xmx$SERVER_MEMORY/g" "$JSON_FILE"
        
        # Ensure Steam is enabled (replace =0 with =1 if present)
        sed -i 's/-Dzomboid.steam=0/-Dzomboid.steam=1/g' "$JSON_FILE"
        
        echo "Updated $JSON_FILE with Memory=$SERVER_MEMORY and Steam=Enabled"
    else
        echo "Warning: $JSON_FILE not found."
    fi
}

generate_service() {
    echo "Generating systemd service file..."
    SERVICE_FILE="$SERVICE_NAME.service"
    USER_NAME=$(whoami)

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Project Zomboid Server ($SERVICE_NAME)
After=network.target

[Service]
Type=simple
User=$USER_NAME
WorkingDirectory=$INSTALL_DIR
# Using the Steam-enabled script with self-contained data directory
ExecStart=$INSTALL_DIR/start-server-steam.sh -adminpassword password -servername servertest -cachedir=$INSTALL_DIR/Zomboid
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    echo "Service file '$SERVICE_FILE' generated."
    echo "To install: sudo mv $SERVICE_FILE /etc/systemd/system/ && sudo systemctl daemon-reload"
}

install_java_agent() {
    JAR_PATH="$1"
    if [ -z "$JAR_PATH" ]; then
        echo "Usage: $0 install-agent <path_to_jar>"
        exit 1
    fi

    if [ ! -f "$JAR_PATH" ]; then
        echo "Error: Jar file not found at $JAR_PATH"
        exit 1
    fi
    
    check_deps
    
    JAR_NAME=$(basename "$JAR_PATH")
    TARGET_DIR="$INSTALL_DIR/java"
    TARGET_JAR="java/$JAR_NAME" # Relative path for JSON config
    
    echo "Installing Java Agent: $JAR_NAME"
    mkdir -p "$TARGET_DIR"
    cp "$JAR_PATH" "$TARGET_DIR/$JAR_NAME"
    
    JSON_FILE="$INSTALL_DIR/ProjectZomboid64.json"
    if [ ! -f "$JSON_FILE" ]; then
        echo "Error: $JSON_FILE not found. Install server first."
        exit 1
    fi

    echo "Patching $JSON_FILE..."
    # Export variables for python script
    export CONFIG_PATH="$JSON_FILE"
    export JAR_REL_PATH="$TARGET_JAR"
    
    python3 -c '
import json
import os
import sys

config_path = os.environ["CONFIG_PATH"]
jar_rel_path = os.environ["JAR_REL_PATH"]
agent_arg = f"-javaagent:{jar_rel_path}"

try:
    with open(config_path, "r") as f:
        data = json.load(f)

    vm_args = data.get("vmArgs", [])
    classpath = data.get("classpath", [])
    updated = False

    # Check/Add vmArgs
    if agent_arg not in vm_args:
        print(f"Adding {agent_arg} to vmArgs")
        vm_args.append(agent_arg)
        data["vmArgs"] = vm_args
        updated = True
    else:
        print(f"Agent argument already present.")

    # Check/Add classpath
    if jar_rel_path not in classpath:
        print(f"Adding {jar_rel_path} to classpath")
        classpath.append(jar_rel_path)
        data["classpath"] = classpath
        updated = True
    else:
        print(f"Classpath entry already present.")

    if updated:
        with open(config_path, "w") as f:
            json.dump(data, f, indent=4)
        print("Configuration updated successfully.")
    else:
        print("Configuration already up to date.")

except Exception as e:
    print(f"Error updating JSON: {e}")
    sys.exit(1)
'
    echo "Agent installation complete."
}

open_editor() {
    FILE_PATH="$1"
    if [ ! -f "$FILE_PATH" ]; then
        echo "Error: File not found: $FILE_PATH"
        return
    fi
    
    EDITOR=${EDITOR:-nano}
    echo "Opening $FILE_PATH with $EDITOR..."
    $EDITOR "$FILE_PATH"
}

cmd_edit_config() {
    echo "=== Editing Server Config (servertest.ini) ==="
    CONFIG_FILE="$ZOMBOID_DATA_DIR/Server/servertest.ini"
    open_editor "$CONFIG_FILE"
}

cmd_edit_sandbox() {
    echo "=== Editing Sandbox Options (servertest_SandboxVars.lua) ==="
    SANDBOX_FILE="$ZOMBOID_DATA_DIR/Server/servertest_SandboxVars.lua"
    open_editor "$SANDBOX_FILE"
}

cmd_setup_agent() {
    echo "=== Building & Installing ResetZone Agent ==="
    
    REPO_ROOT="$1"
    
    # 1. Try provided argument
    if [ -n "$REPO_ROOT" ]; then 
        if [ ! -d "$REPO_ROOT/System/JavaAgent" ]; then
            echo "Error: ResetZone source not found at provided path: $REPO_ROOT"
            exit 1
        fi
    # 2. Try current directory
    elif [ -d "./System/JavaAgent" ]; then
        REPO_ROOT="."
    # 3. Try default clone location
    elif [ -d "$HOME/ResetZone/System/JavaAgent" ]; then
        REPO_ROOT="$HOME/ResetZone"
        echo "Found ResetZone source at: $REPO_ROOT"
    else
        echo "Error: Could not locate ResetZone source code."
        echo "Please run from the repo folder OR provide the path."
        echo "Usage: pz_manager setup-agent [path_to_repo]"
        exit 1
    fi
    
    REPO_JAVA_DIR="$REPO_ROOT/System/JavaAgent"

    echo "Building Agent in $REPO_JAVA_DIR..."
    if [ -f "$REPO_JAVA_DIR/build.sh" ]; then
        chmod +x "$REPO_JAVA_DIR/build.sh"
        # Run build script inside its directory
        (cd "$REPO_JAVA_DIR" && ./build.sh)
    else
        echo "Error: build.sh not found."
        exit 1
    fi
    
    JAR_FILE="$REPO_JAVA_DIR/ResetZoneInjector.jar"
    if [ ! -f "$JAR_FILE" ]; then
        echo "Error: Build failed? Expected $JAR_FILE"
        exit 1
    fi
    
    echo "Build successful. Installing..."
    install_java_agent "$JAR_FILE"
}

# --- Commands ---

cmd_install() {
    echo "=== Installing Project Zomboid Server ==="
    check_deps
    install_steamcmd
    
    echo "Downloading Server (Branch: $BRANCH)..."
    "$STEAMCMD_DIR/steamcmd.sh" +force_install_dir "$INSTALL_DIR" +login anonymous +app_update $APP_ID -beta $BRANCH validate +quit
    
    configure_server
    generate_service
    
    echo ""
    echo "Installation Complete."
    echo "Don't forget to install the service file generated in this directory!"
}

cmd_update() {
    echo "=== Updating Project Zomboid Server ==="
    install_steamcmd
    echo "Updating Server Files..."
    "$STEAMCMD_DIR/steamcmd.sh" +force_install_dir "$INSTALL_DIR" +login anonymous +app_update $APP_ID -beta $BRANCH validate +quit
    configure_server
    echo "Update Complete. You may need to restart the service."
}

cmd_backup() {
    echo "=== Backing up Server Data ==="
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/pz_backup_$TIMESTAMP.tar.gz"
    
    if [ -d "$ZOMBOID_DATA_DIR" ]; then
        echo "Backing up $ZOMBOID_DATA_DIR to $BACKUP_FILE..."
        tar -czf "$BACKUP_FILE" -C "$(dirname "$ZOMBOID_DATA_DIR")" "$(basename "$ZOMBOID_DATA_DIR")"
        echo "Backup created successfully."
    else
        echo "Error: Data directory $ZOMBOID_DATA_DIR not found."
    fi
}

cmd_restore() {
    echo "=== Restoring Server Data ==="
    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        echo "No backups found in $BACKUP_DIR"
        exit 1
    fi

    echo "Available backups:"
    ls -1 "$BACKUP_DIR"
    echo ""
    read -p "Enter backup filename to restore: " BACKUP_NAME
    
    FULL_PATH="$BACKUP_DIR/$BACKUP_NAME"
    if [ -f "$FULL_PATH" ]; then
        echo "Restoring from $FULL_PATH..."
        # Warn user
        read -p "WARNING: This will overwrite current data in $ZOMBOID_DATA_DIR. Continue? (y/N) " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            mkdir -p "$(dirname "$ZOMBOID_DATA_DIR")"
            tar -xzf "$FULL_PATH" -C "$(dirname "$ZOMBOID_DATA_DIR")"
            echo "Restore complete."
        else
            echo "Restore cancelled."
        fi
    else
        echo "Error: File not found."
    fi
}

cmd_service() {
    ACTION=$1
    echo "Running: sudo systemctl $ACTION $SERVICE_NAME"
    sudo systemctl "$ACTION" "$SERVICE_NAME"
}

cmd_status() {
    sudo systemctl status "$SERVICE_NAME"
}

cmd_console() {
    echo "Tailing logs (Ctrl+C to exit)..."
    journalctl -u "$SERVICE_NAME" -f
}

# --- Main ---

case "$1" in
    install)
        cmd_install
        ;;
    update)
        cmd_update
        ;;
    backup)
        cmd_backup
        ;;
    restore)
        cmd_restore
        ;;
    start)
        cmd_service "start"
        ;;
    stop)
        cmd_service "stop"
        ;;
    restart)
        cmd_service "restart"
        ;;
    status)
        cmd_status
        ;;
    console|logs)
        cmd_console
        ;;
    install-agent)
        install_java_agent "$2"
        ;;
    setup-agent)
        cmd_setup_agent "$2"
        ;;
    edit-config)
        cmd_edit_config
        ;;
    edit-sandbox)
        cmd_edit_sandbox
        ;;
    *)
        echo "Usage: $0 {install|update|backup|restore|start|stop|restart|status|console|configure|install-agent|edit-config|edit-sandbox|setup-agent}"
        echo ""
        echo "Commands:"
        echo "  install       - Install dependencies, server files, and generate service"
        echo "  update        - Update server files via SteamCMD"
        echo "  setup-agent   - Build & Install ResetZone Agent (Auto-detects source)"
        echo "  install-agent - Install a Java Agent Jar (e.g. for ResetZone)"
        echo "  backup        - Backup '~/Zomboid' folder"
        echo "  restore       - Restore '~/Zomboid' folder"
        echo "  start/stop    - Control systemd service"
        echo "  edit-config   - Edit servertest.ini"
        echo "  edit-sandbox  - Edit servertest_SandboxVars.lua"
        exit 1
        ;;
    configure)
        configure_server
        ;;
    *)
        echo "Usage: $0 {install|update|backup|restore|start|stop|restart|status|console|configure|install-agent}"
        echo ""
        echo "Commands:"
        echo "  install       - Install dependencies, server files, and generate service"
        echo "  update        - Update server files via SteamCMD and re-apply fixes"
        echo "  backup        - Backup '~/Zomboid' folder to '$BACKUP_DIR'"
        echo "  restore       - Restore '~/Zomboid' folder from backup"
        echo "  start         - Start the systemd service"
        echo "  stop          - Stop the systemd service"
        echo "  restart       - Restart the systemd service"
        echo "  status        - Check service status"
        echo "  console       - View live server logs (journalctl)"
        echo "  configure     - Re-apply memory and steam settings"
        echo "  install-agent - Install a Java Agent JAR (e.g. ResetZone)"
        exit 1
        ;;
esac
