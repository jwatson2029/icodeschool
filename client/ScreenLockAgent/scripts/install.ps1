#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Installs the Screen Lock Agent on this Windows PC.

.DESCRIPTION
  Downloads the latest release from GitHub (or uses a local folder),
  copies files to Program Files, registers auto-start on boot/logon/unlock,
  and starts the agent immediately.

  Note: `#Requires -RunAsAdministrator` is ignored when this script is run via
  `irm ... | iex`. An explicit elevation check below handles that case.

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
$InstallScriptUrl = "https://raw.githubusercontent.com/$Repo/main/client/ScreenLockAgent/scripts/install.ps1"
$latestZipUrl = "https://github.com/$Repo/releases/latest/download/ScreenLockAgent-win-x64.zip"

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
            "-Repo", $Repo,
            "-InstallPath", $InstallPath
        )
        if ($LocalPath -ne "") {
            $argList += @("-LocalPath", $LocalPath)
        }

        try {
            $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru
            exit $proc.ExitCode
        } catch {
            throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun the installer."
        }
    }

    if ($LocalPath -ne "") {
        throw "This installer must run as Administrator. Right-click PowerShell → Run as administrator, then: .\install.ps1 -LocalPath `"$LocalPath`""
    }

    # Piped via irm | iex — $PSCommandPath is empty; re-fetch in an elevated window
    $elevatedCommand = "irm '$InstallScriptUrl' | iex"
    try {
        $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $elevatedCommand
        ) -Wait -PassThru
        exit $proc.ExitCode
    } catch {
        throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun: irm $InstallScriptUrl | iex"
    }
}

function Stop-ScreenLockAgentProcess {
    Write-Step "Stopping existing agent (if running)"

    # Prefer stopping via Task Scheduler first (avoids fighting a Highest-privilege process)
    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    $procs = @(Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        return
    }

    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
            # Elevated agent / different session: taskkill is more reliable than Stop-Process
            $null = & taskkill.exe /F /T /PID $proc.Id 2>&1
        }
    }

    Start-Sleep -Seconds 1

    $stillRunning = @(Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue)
    if ($stillRunning.Count -gt 0) {
        $pids = ($stillRunning | ForEach-Object { $_.Id }) -join ", "
        throw @"
Could not stop ScreenLockAgent (PID(s): $pids) — Access denied.
End the process in Task Manager (Details → ScreenLockAgent.exe → End task),
or reboot, then rerun this installer from an elevated PowerShell window.
"@
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

function Install-FromDirectory($SourceDir) {
    if (-not (Test-Path "$SourceDir\ScreenLockAgent.exe")) {
        throw "ScreenLockAgent.exe not found in $SourceDir"
    }

    Stop-ScreenLockAgentProcess

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

if (-not (Test-IsAdministrator)) {
    Request-AdministratorElevation
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
