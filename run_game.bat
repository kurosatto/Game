@echo off
title Evo Roguelike: Primordial Genesis
echo Starting Evo Roguelike in Godot 4...
echo.
echo Controls:
echo   WASD - Move Primordial Organism
echo   IJKL / Arrow Keys / Left-Click - Shoot Bio-Plasma Fluids
echo   Spacebar / Shift / Right-Click - Bio-Hydro Dash
echo   E / Q / Middle-Click - Bio-Electric Discharge (Clear Bullets & Stun Knockback)
echo   R - Restart genetic lineage (on Extinction / Apex Evolution)
echo.

:: Strip trailing backslash from directory path
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo Launching game from: "%PROJECT_DIR%"
echo.

set "GODOT_EXE="

:: 1. Check if godot_console is in PATH
where godot_console.exe >nul 2>nul
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where godot_console.exe') do (
        set "GODOT_EXE=%%i"
        goto :found
    )
)

:: 2. Check if godot is in PATH
where godot.exe >nul 2>nul
if %errorlevel% equ 0 (
    for /f "delims=" %%i in ('where godot.exe') do (
        set "GODOT_EXE=%%i"
        goto :found
    )
)

:: 3. Check Winget installation directory for console executable
for /d %%d in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
    for %%f in ("%%d\*console.exe") do (
        set "GODOT_EXE=%%f"
        goto :found
    )
    for %%f in ("%%d\*.exe") do (
        set "GODOT_EXE=%%f"
        goto :found
    )
)

:: 4. Check known WinGet package path
if exist "C:\Users\mesta\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe" (
    set "GODOT_EXE=C:\Users\mesta\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
    goto :found
)

:: 5. Check Downloads folder for unpacked or direct Godot
for /r "%USERPROFILE%\Downloads" %%f in (*godot*.exe) do (
    set "GODOT_EXE=%%f"
    goto :found
)

:found
if "%GODOT_EXE%"=="" (
    echo [ERROR] Godot executable could not be found!
    echo Please ensure Godot 4 is installed.
    pause
    exit /b 1
)

echo Found Godot at: "%GODOT_EXE%"
"%GODOT_EXE%" --path "%PROJECT_DIR%"

echo.
echo Game exited.
pause

