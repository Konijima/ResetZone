import os
import time
import subprocess
from datetime import datetime, timedelta
from .rcon import RCONClient
from . import backup_tools

def get_next_restart_info(mgr):
    restart_times = mgr.config.get("restart_times", [0, 6, 12, 18])
    if not restart_times: return "Not Scheduled"
    
    now = datetime.now()
    current_hour = now.hour
    current_min = now.minute
    
    # Calculate next restart
    min_diff = 9999
    
    for h in restart_times:
        diff = (h * 60) - ((current_hour * 60) + current_min)
        if diff <= 0: diff += 24 * 60
        if diff < min_diff: min_diff = diff
            
    hours_left = min_diff // 60
    mins_left = min_diff % 60
    
    dt_next = now + timedelta(minutes=min_diff)
    time_str = dt_next.strftime("%H:%M")
    
    return f"{time_str} (in {hours_left}h {mins_left}m)"

def run_scheduler(mgr):
    print(f"[Scheduler] Starting...")
    while True:
        try:
            check_schedule(mgr)
        except Exception as e:
            print(f"[Scheduler] Error: {e}")
        time.sleep(60) # Constant Sleep 60s

def check_schedule(mgr):
    now = datetime.now()
    current_hour = now.hour
    current_min = now.minute
    
    restart_times = mgr.config.get("restart_times", [0, 6, 12, 18])
    
    # Calculate next restart
    min_diff = 9999
    
    for h in restart_times:
        diff = (h * 60) - ((current_hour * 60) + current_min)
        if diff <= 0: diff += 24 * 60
        if diff < min_diff: min_diff = diff
        
    minutes_left = min_diff
    
    # Connect to RCON for current minute check
    # We instantiate it but only connect if we need to warn
    rcon = RCONClient(mgr.config["rcon_host"], mgr.config["rcon_port"], mgr.config["rcon_password"])

    if minutes_left in [60, 30, 10, 5, 1]:
        print(f"[Scheduler] Warning: Restart in {minutes_left} min")
        rcon.broadcast(f"WARNING: Server Restart & Cleanup in {minutes_left} minutes!")
        
    if minutes_left <= 0:
        print("[Scheduler] Restarting NOW!")
        rcon.broadcast("Server restarting NOW! Please Wait...")
        time.sleep(5)
        rcon.quit()
        
        # Wait for stop
        time.sleep(30)
        print("[Scheduler] Stopping service...")
        svc = mgr.config["service_name"]
        subprocess.run(f"sudo systemctl stop {svc}", shell=True)
        
        # AUTO BACKUP
        try:
            backup_tools.perform_auto_backup(mgr)
        except Exception as e:
            print(f"[Scheduler] Auto-backup failed: {e}")
            
        # CLEANUP MAP
        perform_map_cleanup(mgr)
        
        print("[Scheduler] Starting service...")
        subprocess.run(f"sudo systemctl start {svc}", shell=True)
        time.sleep(60) # Wait a bit so we don't trigger again immediately

def perform_map_cleanup(mgr):
    print("[Scheduler] Performing Map Cleanup...")
    install_dir = mgr.config['install_dir']
    
    list_file = os.path.join(install_dir, "Zomboid/Lua/reset_zones.txt")
    if not os.path.exists(list_file):
        list_file = os.path.join(install_dir, "Zomboid/reset_zones.txt")
    
    if not os.path.exists(list_file):
            print(f"[Scheduler] List file not found at {list_file}. Skipping cleanup.")
            return

    save_dir = os.path.join(install_dir, f"Zomboid/Saves/Multiplayer/{mgr.config['server_name']}")
    if not os.path.exists(save_dir):
        print(f"[Scheduler] Save dir not found: {save_dir}")
        return
        
    with open(list_file, 'r') as f:
        lines = f.readlines()
        
    count = 0
    for line in lines:
        xy = line.strip() # "10_10"
        if not xy: continue
        
        # Targets
        targets = [
            f"map_{xy}.bin",
            f"chunkdata_{xy}.bin",
            f"zpop_{xy}.bin"
        ]
        
        for t in targets:
            p = os.path.join(save_dir, t)
            if os.path.exists(p):
                try:
                    os.remove(p)
                    count += 1
                    print(f"Deleted {t}")
                except Exception as e:
                    print(f"Failed to delete {t}: {e}")
                    
    print(f"[Scheduler] Cleanup Complete. Deleted {count} files.")
