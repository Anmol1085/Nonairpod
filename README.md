# Oppo Enco Air 3 Pro Battery Monitor 🎧

A lightweight macOS menu bar application to monitor the battery levels of your **Oppo Enco Air 3 Pro** earbuds.

## Download 📥

**[Download OppoEncoMonitor.zip](OppoEncoMonitor.zip)**
_(Unzip and drag to Applications)_

## Features ✨

- **Real-time Battery Monitoring**: Displays Left, Right, and Case battery levels.
- **Menu Bar Integration**: Quick glanceable status icon.
- **Charging Status**: Visual indicators (⚡️) when earbuds or case are charging.
- **Smart Connection**: Automatically reconnects to the earbuds when they are nearby.
- **L/R Swap**: Toggle to swap Left and Right earbud display if your device reports them inverted.
- **Optimized Performance**: Built with Swift for native performance, minimal memory usage, and no external dependencies.

## Installation 🛠️

### Option 1: Build from Terminal (Recommended)

1.  Open Terminal in this directory.
2.  Run the build script:
    ```bash
    ./build_app.sh
    ```
3.  The app will be compiled to `Build/OppoEncoMonitor.app`.
4.  Drag `OppoEncoMonitor.app` to your **Applications** folder.
5.  Run it!

### Option 2: Xcode

1.  Create a new SwiftUI macOS project.
2.  Copy `BatteryMonitor.swift` and `OppoEncoMonitorApp.swift` into the project.
3.  Add `Privacy - Bluetooth Always Usage Description` to `Info.plist`.
4.  Build and Run.

## Permissions 🔒

On first launch, macOS will ask for **Bluetooth Permission**. You must allow this for the app to detect your earbuds.
If you accidentally denied it, go to **System Settings > Privacy & Security > Bluetooth** and enable it for `OppoEncoMonitor`.

## Troubleshooting ❓

- **No Battery Data**: Open the charging case lid. The earbuds only broadcast status when active or the case is open.
- **Wrong Earbuds**: If Left acts like Right, use the "Swap L/R" button in the menu.
- **Not Connecting**: Ensure your earbuds are paired to your Mac via standard Bluetooth settings first.
