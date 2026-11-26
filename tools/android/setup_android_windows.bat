<# : batch portion
@echo off
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((Get-Content -LiteralPath '%~f0' -Raw)))"
pause
exit /b
#>
<#
  Sets up a Windows PC for Android development with Godot 4.7.

  Installs (all per-user, no admin needed except for the JDK installer):
    - OpenJDK 17 (Eclipse Temurin, via winget)
    - Android SDK command-line tools
    - SDK packages required by Godot 4.7:
        platform-tools, build-tools;35.0.1, platforms;android-35,
        cmake;3.10.2.4988404, ndk;28.1.13356709
  Sets JAVA_HOME / ANDROID_HOME and adds adb to the user PATH.

  This is a single self-contained file: the lines above launch PowerShell,
  which runs the rest of this file. Just double-click it.
#>
param(
    [string]$SdkRoot = "$env:LOCALAPPDATA\Android\Sdk"
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # makes Invoke-WebRequest much faster

$SdkPackages = @(
    'platform-tools',
    'build-tools;35.0.1',
    'platforms;android-35',
    'cmake;3.10.2.4988404',
    'ndk;28.1.13356709'
)
# Used only if the latest version can't be looked up online.
$FallbackCmdlineToolsZip = 'commandlinetools-win-13114758_latest.zip'

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

# --- 1. JDK 17 ---------------------------------------------------------------
Step 'Checking for JDK 17'
function Find-Jdk17 {
    $roots = @("$env:ProgramFiles\Eclipse Adoptium", "$env:ProgramFiles\Java", "$env:ProgramFiles\Microsoft")
    foreach ($r in $roots) {
        if (Test-Path $r) {
            $d = Get-ChildItem $r -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending | Select-Object -First 1
            if ($d -and (Test-Path "$($d.FullName)\bin\java.exe")) { return $d.FullName }
        }
    }
    return $null
}

$JavaHome = Find-Jdk17
if (-not $JavaHome) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw 'winget not found. Install JDK 17 from https://adoptium.net/temurin/releases/?version=17 and re-run this script.'
    }
    Write-Host 'Installing Eclipse Temurin JDK 17 with winget...'
    winget install --id EclipseAdoptium.Temurin.17.JDK -e --accept-source-agreements --accept-package-agreements
    $JavaHome = Find-Jdk17
    if (-not $JavaHome) { throw 'JDK 17 install finished but it could not be found. Open a new terminal and re-run.' }
}
Write-Host "JDK 17: $JavaHome"
$env:JAVA_HOME = $JavaHome
$env:Path = "$JavaHome\bin;$env:Path"

# --- 2. Android command-line tools -------------------------------------------
$SdkManager = "$SdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
if (-not (Test-Path $SdkManager)) {
    Step "Installing Android command-line tools into $SdkRoot"
    $zipName = $FallbackCmdlineToolsZip
    try {
        $xml = (Invoke-WebRequest -UseBasicParsing 'https://dl.google.com/android/repository/repository2-1.xml').Content
        $found = [regex]::Matches($xml, 'commandlinetools-win-(\d+)_latest\.zip') |
                 Sort-Object { [int]$_.Groups[1].Value } -Descending | Select-Object -First 1
        if ($found) { $zipName = $found.Value }
    } catch { Write-Host 'Could not look up latest version; using fallback.' }

    $tmp = Join-Path $env:TEMP 'android-cmdline-tools'
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $zip = Join-Path $tmp $zipName
    Write-Host "Downloading $zipName..."
    Invoke-WebRequest -UseBasicParsing "https://dl.google.com/android/repository/$zipName" -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp -Force

    # The zip contains "cmdline-tools/"; sdkmanager expects "cmdline-tools/latest/".
    New-Item -ItemType Directory -Force "$SdkRoot\cmdline-tools" | Out-Null
    Remove-Item "$SdkRoot\cmdline-tools\latest" -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item "$tmp\cmdline-tools" "$SdkRoot\cmdline-tools\latest"
    Remove-Item $tmp -Recurse -Force
}

# --- 3. SDK packages ---------------------------------------------------------
# Newer command-line tools ship the "android" CLI and turn sdkmanager into a
# wrapper around it. Its package names use "/" instead of ";" (build-tools/35.0.1).
$AndroidCli = Get-ChildItem "$SdkRoot\cmdline-tools\latest" -Recurse -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -in 'android.exe', 'android.bat', 'android.cmd' } |
              Select-Object -First 1 -ExpandProperty FullName

Step 'Installing SDK packages (NDK is large, this can take a while)'
if ($AndroidCli) {
    Write-Host "Using Android CLI: $AndroidCli"
    $packages = $SdkPackages | ForEach-Object { $_ -replace ';', '/' }
    & $AndroidCli --sdk="$SdkRoot" sdk install @packages
} else {
    $yes = ("y`n" * 50)
    $yes | & $SdkManager --sdk_root="$SdkRoot" --licenses | Out-Null
    # Quote each name so cmd.exe doesn't split it at the ";".
    $packages = $SdkPackages | ForEach-Object { '"' + $_ + '"' }
    & $SdkManager --sdk_root="$SdkRoot" @packages
}

# The tools don't always fail with an error code, so check the folders directly.
$missing = $SdkPackages | Where-Object { -not (Test-Path (Join-Path $SdkRoot ($_ -replace ';', '\'))) }
if ($missing) {
    throw "These SDK packages did not install: $($missing -join ', ')"
}
Write-Host 'All SDK packages installed.'

# --- 4. Environment variables ------------------------------------------------
Step 'Setting user environment variables'
[Environment]::SetEnvironmentVariable('JAVA_HOME', $JavaHome, 'User')
[Environment]::SetEnvironmentVariable('ANDROID_HOME', $SdkRoot, 'User')
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$platformTools = "$SdkRoot\platform-tools"
if (-not $userPath -or ($userPath -split ';') -notcontains $platformTools) {
    $newPath = if ($userPath) { "$($userPath.TrimEnd(';'));$platformTools" } else { $platformTools }
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}

# --- 5. Summary --------------------------------------------------------------
& "$platformTools\adb.exe" version | Select-Object -First 1
Write-Host ''
Write-Host 'Done! Now set these in Godot: Editor > Editor Settings > Export > Android' -ForegroundColor Green
Write-Host "  Java SDK Path    : $JavaHome"
Write-Host "  Android SDK Path : $SdkRoot"
Write-Host 'Then: Editor > Manage Export Templates > Download and Install.'
Write-Host 'Open a NEW terminal so the updated PATH (adb) takes effect.'
