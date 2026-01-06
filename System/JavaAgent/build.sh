#!/bin/bash
set -e

# Define directories
SRC_DIR="src"
OUT_DIR="out"
JAR_NAME="ResetZoneInjector.jar"

# Clean
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

# Compile
echo "Compiling..."
# No classpath needed now as we use Reflection for PZ classes
javac -d "$OUT_DIR" $(find "$SRC_DIR" -name "*.java")

# Package
echo "Packaging..."
jar cvfm "$JAR_NAME" manifest.txt -C "$OUT_DIR" .

echo "Build complete: $JAR_NAME"
