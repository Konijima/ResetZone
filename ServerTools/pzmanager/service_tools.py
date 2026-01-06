import os
import sys
import subprocess
from .const import *
from .utils import print_header, run_cmd, InteractiveMenu, clear_screen, format_info_box

def manage_service_control(mgr):
    last_idx = 0
    while True:
        def info():
            svc = mgr.config["service_name"]
            status_out = subprocess.run(f"systemctl is-active {svc}", shell=True, capture_output=True, text=True).stdout.strip()
            color = C_GREEN if status_out == "active" else C_RED
            return format_info_box({
                "Service": f"{C_BOLD}{svc}{C_RESET}",
                "Status": f"{color}{status_out}{C_RESET}"
            })
        
        items = [
            ("Start", '1'),
            ("Stop", '2'),
            ("Restart", '3'),
            ("View Logs", '4'),
            ("Install Service File", '5'),
            ("Install Scheduler (Auto-Restart)", '6'),
            ("Back", 'b')
        ]

        menu = InteractiveMenu(items, title="Service Control", info_text=info, default_index=last_idx)
        c = menu.show()
        last_idx = menu.selected
        
        svc = mgr.config["service_name"]
        if c == '1': run_cmd(f"sudo systemctl start {svc}", shell=True, interactive=mgr.interactive)
        elif c == '2': run_cmd(f"sudo systemctl stop {svc}", shell=True, interactive=mgr.interactive)
        elif c == '3': run_cmd(f"sudo systemctl restart {svc}", shell=True, interactive=mgr.interactive)
        elif c == '4': 
            clear_screen()
            run_cmd(f"journalctl -u {svc} -f -n 100", shell=True, interactive=mgr.interactive)
        elif c == '5': install_service_file(mgr)
        elif c == '6': install_scheduler_service(mgr)
        elif c == 'b' or c == 'q' or c is None: return

def install_service_file(mgr):
    if mgr.interactive: print_header("Install Service")
    user = os.environ.get("USER", "root")
    install_dir = mgr.config["install_dir"]
    svc_name = mgr.config["service_name"]
    
    content = f"""[Unit]
Description=Project Zomboid Server ({svc_name})
After=network.target

[Service]
Type=simple
User={user}
WorkingDirectory={install_dir}
ExecStart={install_dir}/start-server-steam.sh -adminpassword password -servername {mgr.config['server_name']} -cachedir={install_dir}/Zomboid
Restart=always

[Install]
WantedBy=multi-user.target
"""
    tmp_path = "/tmp/pzserver.service"
    with open(tmp_path, 'w') as f:
        f.write(content)
    
    print("Generated service file.")
    print("Installing to /etc/systemd/system/ (requires sudo)...")
    run_cmd(f"sudo mv {tmp_path} /etc/systemd/system/{svc_name}.service", shell=True, interactive=mgr.interactive)
    run_cmd("sudo systemctl daemon-reload", shell=True, interactive=mgr.interactive)
    print(f"Service {svc_name} installed.")
    mgr.wait_input("Press Enter...")

def install_scheduler_service(mgr):
    if mgr.interactive: print_header("Install Scheduler")
    user = os.environ.get("USER", "root")
    svc_name = mgr.config["service_name"] + "-scheduler"
    # Self path - tricky because now we are a package.
    # We should assume pz_manager.py wrapper is the entry.
    # Or use sys.argv[0] assuming it invoked the wrapper
    self_path = os.path.abspath(sys.argv[0])
    
    content = f"""[Unit]
Description=PZ Scheduler ({svc_name})
After=network.target

[Service]
Type=simple
User={user}
ExecStart=/usr/bin/python3 {self_path} --scheduler
Restart=always

[Install]
WantedBy=multi-user.target
"""
    tmp_path = "/tmp/pzscheduler.service"
    with open(tmp_path, 'w') as f:
        f.write(content)

    print("Installing Scheduler Service...")
    run_cmd(f"sudo mv {tmp_path} /etc/systemd/system/{svc_name}.service", shell=True, interactive=mgr.interactive)
    run_cmd("sudo systemctl daemon-reload", shell=True, interactive=mgr.interactive)
    run_cmd(f"sudo systemctl enable {svc_name}", shell=True, interactive=mgr.interactive)
    run_cmd(f"sudo systemctl start {svc_name}", shell=True, interactive=mgr.interactive)
    print(f"Scheduler {svc_name} installed and started.")
    mgr.wait_input("Press Enter...")
