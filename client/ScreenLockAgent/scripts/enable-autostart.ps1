#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Registers Screen Lock Agent to auto-run on Windows startup, logon, and unlock.

.DESCRIPTION
  Creates a Scheduled Task (At logon + Session unlock) and a Windows Run key
  so ScreenLockAgent.exe starts whenever a user reaches the desktop.

  Does not download or reinstall the agent — the EXE must already exist.
  For a full install (download + copy + autostart), use install.ps1 instead.

  Note: `#Requires -RunAsAdministrator` is ignored when this script is run via
  `irm ... | iex`. An explicit elevation check below handles that case.

.EXAMPLE
  .\enable-autostart.ps1

.EXAMPLE
  .\enable-autostart.ps1 -InstallPath "C:\Program Files\ScreenLockAgent"

.EXAMPLE
  irm https://raw.githubusercontent.com/jwatson2029/icodeschool/main/client/ScreenLockAgent/scripts/enable-autostart.ps1 | iex
#>

param(
    [string]$InstallPath = "$env:ProgramFiles\ScreenLockAgent",
    [string]$Repo = "jwatson2029/icodeschool",
    [switch]$StartNow
)

$ErrorActionPreference = "Stop"
$TaskName = "ScreenLockAgent"
$RunKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RunKeyName = "ScreenLockAgent"
$ScriptUrl = "https://raw.githubusercontent.com/$Repo/main/client/ScreenLockAgent/scripts/enable-autostart.ps1"

function Write-Step($Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-AdministratorElevation {
    Write-Step "Administrator privileges required — re-launching elevated"
    Write-Host "    Approve the UAC prompt if shown." -ForegroundColor Yellow

    if ($PSCommandPath) {
        $argList = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $PSCommandPath,
            "-InstallPath", $InstallPath,
            "-Repo", $Repo
        )
        if ($StartNow) { $argList += "-StartNow" }

        try {
            $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru
            exit $proc.ExitCode
        } catch {
            throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun this script."
        }
    }

    $elevatedCommand = "irm '$ScriptUrl' | iex"
    try {
        $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $elevatedCommand
        ) -Wait -PassThru
        exit $proc.ExitCode
    } catch {
        throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun: irm $ScriptUrl | iex"
    }
}

function New-UnlockTrigger {
    # SessionUnlock = 8 (TASK_SESSION_STATE_CHANGE)
    $cimClass = Get-CimClass -ClassName MSFT_TaskSessionStateChangeTrigger -Namespace Root/Microsoft/Windows/TaskScheduler
    $trigger = New-CimInstance -CimClass $cimClass -ClientOnly
    $trigger.StateChange = 8
    $trigger.Enabled = $true
    return $trigger
}

if (-not (Test-IsAdministrator)) {
    Request-AdministratorElevation
}

$exePath = Join-Path $InstallPath "ScreenLockAgent.exe"
if (-not (Test-Path $exePath)) {
    throw @"
ScreenLockAgent.exe not found at:
  $exePath

Install the agent first (install.ps1), or pass -InstallPath to the folder that contains ScreenLockAgent.exe.
"@
}

Write-Step "Registering scheduled task (logon + unlock)"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$action = New-ScheduledTaskAction -Execute $exePath -WorkingDirectory $InstallPath
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

Write-Step "Adding Windows Run key (starts with Windows)"
Set-ItemProperty -Path $RunKeyPath -Name $RunKeyName -Value "`"$exePath`""

if ($StartNow) {
    Write-Step "Starting agent now"
    $running = @(Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue)
    if ($running.Count -eq 0) {
        Start-Process -FilePath $exePath -WorkingDirectory $InstallPath
    } else {
        Write-Host "    Already running (PID(s): $(($running | ForEach-Object { $_.Id }) -join ', '))" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Auto-start enabled." -ForegroundColor Green
Write-Host "Agent path: $exePath"
Write-Host "Will launch on: Windows startup, user logon, and unlock from lock screen."
Write-Host "Task name: $TaskName"
Write-Host "Run key:  HKLM\...\Run\$RunKeyName"
