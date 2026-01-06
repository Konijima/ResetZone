import os
import sys
import json
import subprocess
from .const import *
from .utils import print_header, run_cmd, InteractiveMenu, format_info_box
from . import steam_tools
from . import service_tools
from . import scheduler
from . import backup_tools
from .mod_manager import InternalModManager

class PZManager:
    def __init__(self, interactive=True):
        self.interactive = interactive
        self.config = {}
        self.load_config()

    def load_config(self):
        if os.path.exists(CONFIG_FILE):
            try:
                with open(CONFIG_FILE, 'r') as f:
                    self.config = json.load(f)
            except Exception as e:
                print(f"{C_RED}Error loading config: {e}{C_RESET}")
                self.config = {}
        
        # Set defaults if missing
        self.config.setdefault("install_dir", DEFAULT_INSTALL_DIR)
        self.config.setdefault("steamcmd_dir", DEFAULT_STEAMCMD_DIR)
        self.config.setdefault("backup_dir", DEFAULT_BACKUP_DIR)
        self.config.setdefault("service_name", DEFAULT_SERVICE_NAME)
        self.config.setdefault("memory", "4g")
        self.config.setdefault("restart_times", [0, 6, 12, 18]) 
        self.config.setdefault("rcon_host", "127.0.0.1")
        self.config.setdefault("rcon_port", 27015)
        self.config.setdefault("rcon_password", "")
        self.config.setdefault("branch", "unstable")
        self.config.setdefault("auto_backup", True)
        self.config.setdefault("backup_retention", 5)
        self.save_config()

    def save_config(self):
        os.makedirs(os.path.dirname(CONFIG_FILE), exist_ok=True)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(self.config, f, indent=4)

    def wait_input(self, msg="Press Enter to continue..."):
        if self.interactive:
            input(msg)
            
    # --- Wrappers for Modules ---
    
    def install_server(self):
        steam_tools.install_server(self)
    
    def manage_service_control(self):
        service_tools.manage_service_control(self)
        
    def run_scheduler(self):
        scheduler.run_scheduler(self)

    def main_menu(self):
        last_index = 0
        while True:
            def info():
                sched_svc = self.config['service_name'] + "-scheduler"
                is_active = False
                try:
                    out = subprocess.run(f"systemctl is-active {sched_svc}", shell=True, capture_output=True, text=True).stdout.strip()
                    is_active = (out == "active")
                except: pass
                
                next_restart = scheduler.get_next_restart_info(self) if is_active else "Scheduler Inactive"
                
                return format_info_box({
                    "Server Dir": self.config['install_dir'],
                    "Service": self.config['service_name'],
                    "Next Restart": next_restart,
                    "Branch": self.config['branch']
                })
            
            # Check if installed
            is_installed = os.path.exists(os.path.join(self.config['install_dir'], "ProjectZomboid64.json"))
            install_label = "Update Server" if is_installed else "Install Server"
            
            items = [
                ("Server Control (Start/Stop/Logs/Scheduler)", '1'),
                ("Configuration (Memory, settings)", '2'),
                ("Mod Manager (Workshop & Mods)", '3'),
                ("Backup / Restore", '5'),
                (install_label, '6'),
                ("Quit", 'q')
            ]

            if not self.interactive:
                # Fallback for non-interactive (just print and exit or use old way - mainly for CLI args path)
                print("Interactive mode required for menu.")
                sys.exit(1)

            menu = InteractiveMenu(items, title="Main Menu", info_text=info, default_index=last_index)
            choice = menu.show()
            last_index = menu.selected

            if choice == '1': self.manage_service_control()
            elif choice == '2': self.submenu_config()
            elif choice == '3': self.manage_mods()
            elif choice == '5': self.submenu_backup()
            elif choice == '6': self.install_server()
            elif choice == 'q' or choice is None:
                print("Bye.")
                sys.exit(0)

    def submenu_config(self):
        last_index = 0
        while True:
            def info():
                return format_info_box({
                    "Current Memory": self.config['memory'],
                    "Restart Schedule": str(self.config['restart_times']),
                    "Auto Backup": str(self.config.get("auto_backup", True)),
                    "Backup Retention": str(self.config.get("backup_retention", 5))
                })

            items = [
                ("Edit servertest.ini", '1'),
                ("Edit Sandbox Vars", '2'),
                (f"Change Memory Limit", '3'),
                (f"Edit Restart Schedule", '4'),
                (f"Toggle Auto Backup", 'toggle_backup'),
                (f"Set Backup Retention", 'set_retention'),
                (f"RCON Settings", '5'),
                ("Back", 'b')
            ]

            menu = InteractiveMenu(items, title="Configuration", info_text=info, default_index=last_index)
            choice = menu.show()
            last_index = menu.selected

            if choice == 'b' or choice == 'q' or choice is None: return
            elif choice == '1':
                p = os.path.join(self.config['install_dir'], "Zomboid/Server/servertest.ini")
                run_cmd(f"nano {p}", shell=True)
            elif choice == '2':
                p = os.path.join(self.config['install_dir'], "Zomboid/Server/servertest_SandboxVars.lua")
                run_cmd(f"nano {p}", shell=True)
            elif choice == '3':
                val = input(f"Enter memory (e.g. 4g, 8192m) [Current: {self.config['memory']}]: ").strip()
                if val:
                    self.config['memory'] = val
                    self.save_config()
                    steam_tools.configure_server_files(self)
            elif choice == '4':
                print(f"Current Schedule: {self.config['restart_times']}")
                val = input("Enter hours (comma separated, e.g. 0,6,12,18): ").strip()
                if val:
                    try:
                        self.config['restart_times'] = [int(x.strip()) for x in val.split(",")]
                        self.save_config()
                    except:
                        print("Invalid format.")
                        self.wait_input()
            elif choice == 'toggle_backup':
                curr = self.config.get("auto_backup", True)
                self.config["auto_backup"] = not curr
                self.save_config()
            elif choice == 'set_retention':
                val = input(f"Enter retention count (Default 5) [Current: {self.config.get('backup_retention', 5)}]: ").strip()
                if val.isdigit():
                    self.config["backup_retention"] = int(val)
                    self.save_config()
            elif choice == '5':
                self.submenu_rcon()

    def submenu_rcon(self):
        last_index = 0
        while True:
            def info():
                return format_info_box({
                    "Host": self.config['rcon_host'],
                    "Port": str(self.config['rcon_port']),
                    "Password": '*' * len(self.config['rcon_password']) if self.config['rcon_password'] else '(None)'
                })

            items = [
                ("Change Host", '1'),
                ("Change Port", '2'),
                ("Change Password", '3'),
                ("Back", 'b')
            ]
            
            menu = InteractiveMenu(items, title="RCON Settings", info_text=info, default_index=last_index)
            c = menu.show()
            last_index = menu.selected

            if c == 'b' or c == 'q' or c is None: return
            elif c == '1':
                val = input(f"Host [{self.config['rcon_host']}]: ").strip()
                if val: 
                    self.config['rcon_host'] = val
                    self.save_config()
            elif c == '2':
                val = input(f"Port [{self.config['rcon_port']}]: ").strip()
                if val:
                    try:
                        self.config['rcon_port'] = int(val)
                        self.save_config()
                    except: pass
            elif c == '3':
                val = input("Password: ").strip()
                self.config['rcon_password'] = val
                self.save_config()



    def submenu_backup(self):
        last_index = 0
        while True:
            def info():
                files = backup_tools.get_recent_backups(self)
                data = {"Backup Directory": self.config['backup_dir']}
                
                if not files:
                    data["Status"] = "No backups found"
                else:
                    data["Total Backups"] = str(len(files))
                    # List top 5
                    for i, f in enumerate(files[:5]):
                        size = os.path.getsize(f) / (1024 * 1024) # MB
                        dt = os.path.getmtime(f)
                        date_str = backup_tools.datetime.fromtimestamp(dt).strftime("%Y-%m-%d %H:%M")
                        fname = os.path.basename(f)
                        data[f"#{i+1}"] = f"{fname} ({size:.1f} MB) - {date_str}"
                
                return format_info_box(data)

            items = [
                ("Create Backup", '1'),
                ("Manage Backups (Restore/Delete)", '2'),
                ("Back", 'b')
            ]
            menu = InteractiveMenu(items, title="Backup / Restore", info_text=info, default_index=last_index)
            c = menu.show()
            last_index = menu.selected

            if c == 'b' or c == 'q' or c is None: return
            elif c == '1': backup_tools.backup_data(self)
            elif c == '2': backup_tools.manage_backups_menu(self)

    def manage_mods(self):
        # Initialize internal mod manager if needed
        mm = InternalModManager(self.config['install_dir'], self.config['steamcmd_dir'])
        mm.run()


