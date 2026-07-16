#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Removes the Screen Lock Agent from this Windows PC.

.DESCRIPTION
  Note: `#Requires -RunAsAdministrator` is ignored when this script is run via
  `irm ... | iex`. An explicit elevation check below handles that case.
#>

param(
    [string]$InstallPath = "$env:ProgramFiles\ScreenLockAgent",
    [string]$TaskName = "ScreenLockAgent",
    [string]$Repo = "jwatson2029/icodeschool"
)

$ErrorActionPreference = "Stop"
$RunKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$RunKeyName = "ScreenLockAgent"
$UninstallScriptUrl = "https://raw.githubusercontent.com/$Repo/main/client/ScreenLockAgent/scripts/uninstall.ps1"

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
            "-TaskName", $TaskName,
            "-Repo", $Repo
        )
        try {
            $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait -PassThru
            exit $proc.ExitCode
        } catch {
            throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun uninstall."
        }
    }

    $elevatedCommand = "irm '$UninstallScriptUrl' | iex"
    try {
        $proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-Command", $elevatedCommand
        ) -Wait -PassThru
        exit $proc.ExitCode
    } catch {
        throw "Elevation was cancelled or failed. Right-click PowerShell → Run as administrator, then rerun: irm $UninstallScriptUrl | iex"
    }
}

function Stop-ScreenLockAgentProcess {
    Write-Step "Stopping agent"

    Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

    $procs = @(Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) {
        return
    }

    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction Stop
        } catch {
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
or reboot, then rerun uninstall from an elevated PowerShell window.
"@
    }
}

if (-not (Test-IsAdministrator)) {
    Request-AdministratorElevation
}

Stop-ScreenLockAgentProcess

Write-Step "Removing scheduled task"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Step "Removing Windows Run key"
Remove-ItemProperty -Path $RunKeyPath -Name $RunKeyName -ErrorAction SilentlyContinue

Write-Step "Removing files from $InstallPath"
if (Test-Path $InstallPath) {
    Remove-Item $InstallPath -Recurse -Force
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
