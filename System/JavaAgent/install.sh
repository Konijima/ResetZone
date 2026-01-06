#!/bin/bash
set -e

SERVER_DIR="/home/mathieu/pzserver"
JAR_NAME="ResetZoneInjector.jar"
TARGET_JAR="$SERVER_DIR/java/$JAR_NAME"

echo "Copying $JAR_NAME to $TARGET_JAR..."
cp "$JAR_NAME" "$TARGET_JAR"

echo "Updating ProjectZomboid64.json..."
python3 -c '
import json
import sys
import os

config_path = "/home/mathieu/pzserver/ProjectZomboid64.json"
jar_rel_path = "java/ResetZoneInjector.jar"
agent_arg = f"-javaagent:{jar_rel_path}"

try:
    with open(config_path, "r") as f:
        data = json.load(f)

    vm_args = data.get("vmArgs", [])
    classpath = data.get("classpath", [])

    updated = False

    # Check if agent arg already present
    if agent_arg not in vm_args:
        print(f"Adding {agent_arg} to vmArgs")
        vm_args.append(agent_arg)
        data["vmArgs"] = vm_args
        updated = True
    else:
        print(f"{agent_arg} already present in vmArgs")

    # Check if jar in classpath
    if jar_rel_path not in classpath:
        print(f"Adding {jar_rel_path} to classpath")
        classpath.append(jar_rel_path)
        data["classpath"] = classpath
        updated = True
    else:
        print(f"{jar_rel_path} already present in classpath")

    if updated:
        with open(config_path, "w") as f:
            json.dump(data, f, indent=8) # Indent to try and match existing style if possible
        print("Configuration updated.")
    else:
        print("Configuration already up to date.")

except Exception as e:
    print(f"Error updating JSON: {e}")
    sys.exit(1)
'

echo "Installation complete."
