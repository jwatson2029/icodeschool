#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Installs the Screen Lock Agent on this Windows PC.

.DESCRIPTION
  Downloads the latest release from GitHub (or uses a local folder),
  copies files to Program Files, registers auto-start on boot/logon/unlock,
  and starts the agent immediately.

.EXAMPLE
  irm https://raw.githubusercontent.com/jwatson2029/icodeschool/main/client/ScreenLockAgent/scripts/install.ps1 | iex

.EXAMPLE
  .\install.ps1 -LocalPath "C:\path\to\extracted\zip"
#>

param(
    [string]$Repo = "jwatson2029/icodeschool",
    [string]$InstallPath = "$env:ProgramFiles\ScreenLockAgent",
    [string]$LocalPath = ""
)

$ErrorActionPreference = "Stop"
$TaskName = "ScreenLockAgent"
$RunKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RunKeyName = "ScreenLockAgent"
$latestZipUrl = "https://github.com/$Repo/releases/latest/download/ScreenLockAgent-win-x64.zip"

function Write-Step($Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function New-UnlockTrigger {
    # SessionUnlock = 8 (TASK_SESSION_STATE_CHANGE)
    $cimClass = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
    $trigger = New-CimInstance -CimClass $cimClass -ClientOnly
    $trigger.StateChange = 8
    $trigger.Enabled = $true
    return $trigger
}

function Install-FromDirectory($SourceDir) {
    if (-not (Test-Path "$SourceDir\ScreenLockAgent.exe")) {
        throw "ScreenLockAgent.exe not found in $SourceDir"
    }

    Write-Step "Stopping existing agent (if running)"
    Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue | Stop-Process -Force

    Write-Step "Installing to $InstallPath"
    New-Item -ItemType Directory -Force -Path $InstallPath | Out-Null
    Copy-Item "$SourceDir\*" $InstallPath -Recurse -Force

    $exePath = Join-Path $InstallPath "ScreenLockAgent.exe"

    Write-Step "Registering auto-start (startup, logon, unlock)"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute $exePath -WorkingDirectory $InstallPath

    # After reboot / power-on: Run key + logon trigger start the agent with the user session
    # After lock screen unlock: SessionUnlock trigger restarts it if it was killed
    $logonTrigger = New-ScheduledTaskTrigger -AtLogOn
    $unlockTrigger = New-UnlockTrigger

    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RestartCount 3 `
        -RestartInterval (New-TimeSpan -Minutes 1) `
        -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -MultipleInstances IgnoreNew

    # Interactive session required for tray icon + full-screen lock overlay
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger @($logonTrigger, $unlockTrigger) `
        -Settings $settings `
        -Principal $principal `
        -Description "iCodeSchool classroom screen lock agent (logon + unlock)" | Out-Null

    # Starts after Windows boot when a user reaches the desktop
    Write-Step "Adding Windows Run key (starts with Windows)"
    Set-ItemProperty -Path $RunKeyPath -Name $RunKeyName -Value "`"$exePath`""

    Write-Step "Starting agent now"
    Start-Process -FilePath $exePath -WorkingDirectory $InstallPath

    Write-Host ""
    Write-Host "Install complete." -ForegroundColor Green
    Write-Host "Agent path: $exePath"
    Write-Host "Auto-start: Windows startup, user logon, and unlock from lock screen."
    Write-Host "Check the admin dashboard: https://icodeschool-eight.vercel.app"
}

if ($LocalPath -ne "") {
    Install-FromDirectory (Resolve-Path $LocalPath)
    exit 0
}

$tempRoot = Join-Path $env:TEMP "ScreenLockAgent-install"
$zipPath = Join-Path $tempRoot "ScreenLockAgent-win-x64.zip"
$extractPath = Join-Path $tempRoot "extracted"

Write-Step "Downloading latest release package from $Repo"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
try {
    Invoke-WebRequest -Uri $latestZipUrl -OutFile $zipPath
} catch {
    throw "Failed to download ScreenLockAgent-win-x64.zip from latest release. Ensure a release exists and rerun the 'Build & Release Windows Agent' workflow. Download URL: $latestZipUrl"
}

Write-Step "Extracting"
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Install-FromDirectory $extractPath
