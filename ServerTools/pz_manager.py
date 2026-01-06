#!/usr/bin/env python3
import sys
import os

# Ensure we can import the package
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from pzmanager.core import PZManager
from pzmanager.utils import run_cmd

if __name__ == "__main__":
    try:
        # Check if running interactively
        is_interactive = len(sys.argv) == 1
        
        app = PZManager(interactive=is_interactive)
        
        if len(sys.argv) > 1:
            cmd = sys.argv[1]
            svc = app.config['service_name']
            
            if cmd == "--scheduler":
                app.run_scheduler()
            elif cmd == "start": run_cmd(f"sudo systemctl start {svc}", shell=True, interactive=False)
            elif cmd == "stop": run_cmd(f"sudo systemctl stop {svc}", shell=True, interactive=False)
            elif cmd == "restart": run_cmd(f"sudo systemctl restart {svc}", shell=True, interactive=False)
            elif cmd == "status": run_cmd(f"sudo systemctl status {svc}", shell=True, interactive=False)
            elif cmd == "logs": run_cmd(f"journalctl -u {svc} -f", shell=True, interactive=False)
            elif cmd == "install": app.install_server()
            elif cmd == "backup": app.submenu_backup()
            elif cmd == "help":
                print("Usage: pz_manager [COMMAND]")
                print("\nCommands:")
                print("  start      Start the server service")
                print("  stop       Stop the server service")
                print("  restart    Restart the server service")
                print("  status     Check usage status")
                print("  logs       View server logs")
                print("  install    Run server installer/updater")
                print("  backup     Run backup tool")
                print("\n  --scheduler  Run the scheduler daemon (INTERNAL USE: Do not run manually)")
            else:
                print(f"Unknown command: {cmd}")
                print("Run 'pz_manager help' for usage.")
        else:
            app.main_menu()
    except KeyboardInterrupt:
        print("\nBye.")
        sys.exit(0)
