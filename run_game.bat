@echo off
title Evo Roguelike: Primordial Genesis
echo Starting Evo Roguelike in Godot 4...
echo.
echo Controls:
echo   WASD - Move Primordial Organism
echo   IJKL / Arrow Keys - Shoot Bio-Plasma Fluids
echo   E / Spacebar - Release Volatile Spore (Bomb)
echo   R - Restart genetic lineage (on Extinction / Apex Evolution)
echo.

:: Strip trailing backslash from directory path
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

echo Launching game from: "%PROJECT_DIR%"
echo.

"C:\Users\mesta\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" --path "%PROJECT_DIR%"

echo.
echo Game exited.
pause
