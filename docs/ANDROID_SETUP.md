# Android Development Setup (Windows + Godot 4.7)

This guide sets up a Windows PC to build Android games and apps with Godot,
including this project (Evo Roguelike).

## 1. Run the setup script

Double-click `tools\android\setup_android_windows.bat`, or run this from PowerShell
in the project folder:

```powershell
powershell -ExecutionPolicy Bypass -File tools\android\setup_android_windows.ps1
```

The script installs:

| Component | Version | Location |
|---|---|---|
| OpenJDK (Eclipse Temurin) | 17 | `C:\Program Files\Eclipse Adoptium\jdk-17...` |
| Android SDK command-line tools | latest | `%LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest` |
| Platform-Tools (adb) | latest | `%LOCALAPPDATA%\Android\Sdk\platform-tools` |
| Build-Tools | 35.0.1 | |
| SDK Platform | Android 35 | |
| NDK | r28b (28.1.13356709) | |
| CMake | 3.10.2.4988404 | |

It also sets `JAVA_HOME` and `ANDROID_HOME` and adds `adb` to your PATH.
These versions are the ones the Godot 4.7 docs require. The NDK is a large
download, so the script can take 10–20 minutes.

> **Prefer a GUI?** You can install [Android Studio](https://developer.android.com/studio)
> instead and add the same packages through *Tools → SDK Manager*. You'll
> want Android Studio later anyway if you write native Kotlin/Java apps.

## 2. Configure Godot

1. Open Godot 4.7.1 and this project.
2. **Editor → Manage Export Templates → Download and Install.**
3. **Editor → Editor Settings → Export → Android**, then set:
   - **Java SDK Path**: the JDK folder the script printed, e.g. `C:\Program Files\Eclipse Adoptium\jdk-17.0.x-hotspot`
   - **Android SDK Path**: `%LOCALAPPDATA%\Android\Sdk` (write it out in full, e.g. `C:\Users\<you>\AppData\Local\Android\Sdk`)
   - You can leave the debug keystore empty. Godot creates one automatically.

## 3. Prepare your phone

1. **Settings → About phone** → tap **Build number** 7 times to unlock Developer options.
2. **Settings → System → Developer options** → turn on **USB debugging**.
3. Connect the phone by USB and accept the "Allow USB debugging?" prompt.
4. In a **new** terminal, run `adb devices`. Your phone should show as `device`.
   If it shows `unauthorized`, re-check the prompt on the phone.

Wireless debugging (Android 11+) also works: in Developer options, open
**Wireless debugging**, then run `adb pair <ip:port>` and `adb connect <ip:port>`.

## 4. Export the game

1. **Project → Export… → Add… → Android.**
2. Set **Package → Unique Name**, e.g. `com.yourname.evoroguelike`.
3. With the phone connected, click the **Remote Deploy** (Android) icon at the
   top right of the editor to build and launch it on the phone.
   To get an APK file instead, use **Export Project**.

For a Play Store release, create a release keystore:

```powershell
keytool -genkeypair -v -keystore release.keystore -alias release -keyalg RSA -keysize 2048 -validity 10000
```

Then set it under **Keystore → Release** in the export preset, and export an
AAB (enable **Gradle Build → Use Gradle Build** and set **Export Format** to AAB).
**Never commit the keystore or its password.**

## 5. Notes for this project on mobile

- **Controls:** The game only reads the keyboard right now (WASD, IJKL/arrows,
  E/Space). You'll need on-screen touch controls, such as two virtual joysticks
  (move and shoot) and a bomb button, before it's playable on a phone.
- **Renderer:** The project uses *Forward+* on desktop. Godot uses the
  *Mobile* renderer on Android by default (`rendering/renderer/rendering_method.mobile`),
  which is what you want.
- **Orientation:** Set **Project Settings → Display → Window → Handheld → Orientation**
  to *Landscape* to match the 1920×1080 layout.

## Troubleshooting

- **"Could not install to device"**: uninstall any older copy of the app that
  was signed with a different key, then try again.
- **Godot says the SDK path is invalid**: the folder you pick must contain
  `platform-tools\adb.exe`.
- **`adb` not found**: open a new terminal after running the script so it picks up the updated PATH.
