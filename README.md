# TrueDepth 3D Face Scanner

A native iOS application that leverages Apple's TrueDepth camera system (Face ID hardware) to capture high-accuracy 3D face meshes using ARKit. The scanned model can be interactively viewed in a built-in 3D viewer and exported to standard formats (OBJ, USDZ) for use in Blender, Maya, or other 3D tools.

---

## Table of Contents

- [System Requirements](#system-requirements)
- [Architecture](#architecture)
- [Features](#features)
- [Building from Source](#building-from-source)
- [Installing via Sideloadly](#installing-via-sideloadly)
- [Usage Guide](#usage-guide)
- [File Formats](#file-formats)
- [Developer / Debug Tab](#developer--debug-tab)
- [Project Structure](#project-structure)
- [License](#license)

---

## System Requirements

| Requirement | Minimum |
|---|---|
| Device | iPhone X or later (TrueDepth camera required) |
| iOS Version | 18.0+ |
| Xcode | 16.0+ (for building from source) |
| Swift | 5.0+ |

The app requires a physical device with a TrueDepth camera (Face ID). It will not function on the iOS Simulator or devices without Face ID hardware.

---

## Architecture

The application follows an MVVM (Model-View-ViewModel) architecture built entirely with Swift and SwiftUI.

```
TrueDepth3DScanner/
|-- App/                    # SwiftUI app entry point
|-- Models/                 # Data models (ScanDirection, FaceScanSession)
|-- ViewModels/             # Business logic (ScannerViewModel, DeveloperViewModel)
|-- Views/                  # SwiftUI views (Scanner, Viewer3D, Developer, etc.)
|-- Services/               # Core services (Mesh processing, OBJ/USDZ export, Logger, Haptics)
|-- Helpers/                # UIViewRepresentable wrappers (ARViewContainer)
```

### Key Frameworks

- **ARKit** - `ARFaceTrackingConfiguration` for TrueDepth camera face mesh capture
- **SceneKit** - 3D model rendering with physically-based materials and studio lighting
- **ModelIO** - USDZ file generation from mesh data
- **SwiftUI** - Declarative UI with dark mode

---

## Features

### 3D Face Scanning
- Guided multi-directional scan (center, left, right, up, down)
- Real-time face detection with cyan wireframe overlay
- Per-direction progress tracking with visual checklist
- Multi-frame vertex accumulation with weighted blending
- Background mesh processing using Swift concurrency

### 3D Viewer
- Interactive SceneKit viewer with full 360-degree rotation
- Pinch-to-zoom gesture support
- Three-point studio lighting (key, fill, rim)
- Physically-based rendering with skin-tone material
- Vertex and triangle count display

### Export
- **Wavefront OBJ** (.obj + .mtl) - Universal 3D format
- **Apple USDZ** (.usdz) - Native Apple 3D format, Quick Look compatible
- Share via system share sheet (AirDrop, Files, email, etc.)

### Developer Tab
- Centralized logging with severity levels (INFO, WARN, ERROR, DEBUG)
- ARSession error capture and display
- Copy All Logs to clipboard for AI-assisted debugging
- Auto-scroll to latest entries
- Error and warning counters

---

## Building from Source

1. Clone the repository:
   ```
   git clone https://github.com/<your-username>/truedepth-3d-scanner.git
   cd truedepth-3d-scanner
   ```

2. Open the project in Xcode 16+:
   ```
   open TrueDepth3DScanner.xcodeproj
   ```

3. Select your physical iOS device as the build target (simulator is not supported).

4. Build and run (Cmd+R).

---

## Installing via Sideloadly

Pre-built unsigned IPA files are available from the GitHub Releases page.

### Steps

1. Download `TrueDepth3DScanner.ipa` from the latest release on the Releases page.

2. Download and install Sideloadly from https://sideloadly.io/ on your Mac or Windows PC.

3. Connect your iPhone to your computer via USB. Trust the computer on your iPhone if prompted.

4. Open Sideloadly. The connected device should appear in the device dropdown.

5. Drag the downloaded `TrueDepth3DScanner.ipa` file into Sideloadly, or click the IPA icon to browse for it.

6. Enter your Apple ID email address. This is used to sign the app with a free developer certificate. No paid Apple Developer account is required.

7. Click "Start". Enter your Apple ID password when prompted. If you have 2FA enabled, enter the verification code.

8. Wait for the signing and installation process to complete.

9. On your iPhone, go to Settings > General > VPN & Device Management. Find the profile associated with your Apple ID and tap "Trust".

10. The app is now installed and ready to use.

### Notes

- Free Apple ID signing lasts for 7 days. After expiry, repeat the Sideloadly process.
- Paid Apple Developer accounts (\$99/year) provide 1-year signing.
- The app never transmits camera data externally. All processing is on-device.

---

## Usage Guide

1. **Open the app** and navigate to the Scanner tab.

2. **Tap "Start Scan"**. Grant camera permission when prompted.

3. **Follow the on-screen guidance**:
   - Look straight ahead until the center capture completes
   - Slowly turn your head left, then right
   - Slowly look up, then down
   - Each direction shows a progress ring; hold the position until it fills

4. **Processing**: After all five directions are captured, the app automatically processes and merges the mesh data. A loading animation is displayed during this step.

5. **View the result**: The app switches to the 3D Viewer tab. Use gestures to interact:
   - Swipe/drag to rotate the model 360 degrees
   - Pinch to zoom in/out

6. **Export**: Tap the share icon in the toolbar and choose OBJ or USDZ format. The file is shared via the standard iOS share sheet.

---

## File Formats

### Wavefront OBJ (.obj)

Standard ASCII-based 3D geometry format. Includes:
- Vertex positions (v)
- Texture coordinates (vt)
- Vertex normals (vn)
- Triangle face definitions (f)
- Companion material file (.mtl)

Compatible with Blender, Maya, 3ds Max, Unity, Unreal Engine.

### Apple USDZ (.usdz)

Apple's compressed 3D file format based on Universal Scene Description (USD). Features:
- Single-file archive (no external dependencies)
- Physically-based material properties
- Quick Look integration on iOS/macOS
- Compatible with Reality Composer, RealityKit, Blender 3.0+

---

## Developer / Debug Tab

The Developer tab serves as a built-in diagnostic tool:

- All internal log messages are captured with timestamps and severity levels
- ARSession errors, interruptions, and face detection events are logged automatically
- Use "Copy All Logs" to copy the full log text to clipboard
- Paste the log text to an AI assistant or developer for analysis when troubleshooting

---

## Project Structure

```
truedepth-3d-scanner/
|-- TrueDepth3DScanner.xcodeproj/
|   +-- project.pbxproj
|-- TrueDepth3DScanner/
|   |-- App/
|   |   +-- TrueDepth3DScannerApp.swift
|   |-- Views/
|   |   |-- ContentView.swift
|   |   |-- ScannerView.swift
|   |   |-- GuidanceOverlayView.swift
|   |   |-- ProcessingView.swift
|   |   |-- Viewer3DView.swift
|   |   +-- DeveloperView.swift
|   |-- ViewModels/
|   |   |-- ScannerViewModel.swift
|   |   +-- DeveloperViewModel.swift
|   |-- Models/
|   |   |-- FaceScanSession.swift
|   |   +-- ScanDirection.swift
|   |-- Services/
|   |   |-- FaceMeshProcessor.swift
|   |   |-- OBJExporter.swift
|   |   |-- USDZExporter.swift
|   |   |-- LoggerService.swift
|   |   +-- HapticManager.swift
|   |-- Helpers/
|   |   +-- ARViewContainer.swift
|   |-- Assets.xcassets/
|   +-- Info.plist
|-- .github/
|   +-- workflows/
|       +-- ios-sideload-build.yml
+-- README.md
```

---

## License

This project is provided as-is for educational and personal use.
