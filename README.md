# ResetZone

**ResetZone** is a powerful server utility that allows admins to designate specific map areas as "Reset Zones". These zones are automatically wiped and regenerated during server restarts, providing a fresh supply of loot and vehicles for players without wiping the entire map.

## 🌟 Features

*   **In-Game Admin UI:** Easily mark or unmark the current area as a Reset Zone with a single click.
    *   **Red Status:** "RESET ZONE" - This area will be deleted and regenerated next restart.
    *   **Green Status:** "Safe Zone" - Player builds and loot explicitly safe here.
*   **Safehouse Protection:** Prevents (and warns) players from claiming safehouses in designated Reset Zones to avoid losing their bases.
*   **Visual Feedback:** Admins see real-time status of the chunk they are standing in.
*   **External Integration:** Exports the list of marked zones (`reset_zones.txt`) for external tools to process.

## ⚠️ Requirements

**This mod functions in two parts:**
1.  **The Mod (Client/Server):** Visually marks zones and protects players in-game. (This Workshop Item)
2.  **The Manager (Backend):** A separate tool running on the server that actually deletes the map files.

**Without the external manager, this mod essentially acts as a visual marker only.** The map regeneration happens because the *Manager* deletes the chunk files (`map_X_Y.bin`) while the server is offline.

## 🛠️ Installation & Setup

### 1. Subscribe to the Mod
*   **Name:** ResetZone
*   **Mod ID:** `ResetZone`
*   **Workshop ID:** `3639275134`

### 2. Install the Server Manager
To enable the actual resetting functionality, you must install **PZ Manager** on your dedicated server.

**Download & Documentation:**
👉 [PZ Manager Repository](https://github.com/Konijima/PZManager)

The manager handles:
*   Reading the `reset_zones.txt` exported by this mod.
*   Safe server shutdowns.
*   Deleting the specific map chunk files.
*   Backing up data before deletion.

## 🎮 Usage Guide

**For Admins:**
1.  Login as Admin or Moderator.
2.  A small UI panel will appear showing the current Zone Status.
3.  Travel to a location you want to regenerate (e.g., Police Station, Mall).
4.  Click **"Mark Reset"**. The text will turn **RED**.
5.  On the next scheduled restart (handled by PZ Manager), this area will be reset to its original state.

**For Players:**
*   Avoid building bases in areas marked as Reset Zones (if your server provides a map of them).
*   Safehouses cannot be claimed in these zones.

## 🤝 Contribution
Source code is available on GitHub:
[https://github.com/Konijima/ResetZone](https://github.com/Konijima/ResetZone)

