#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Removes the Screen Lock Agent from this Windows PC.
#>

param(
    [string]$InstallPath = "$env:ProgramFiles\ScreenLockAgent",
    [string]$TaskName = "ScreenLockAgent"
)

$ErrorActionPreference = "Stop"

Write-Host "==> Stopping agent" -ForegroundColor Cyan
Get-Process -Name "ScreenLockAgent" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "==> Removing scheduled task" -ForegroundColor Cyan
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "==> Removing files from $InstallPath" -ForegroundColor Cyan
if (Test-Path $InstallPath) {
    Remove-Item $InstallPath -Recurse -Force
}

Write-Host ""
Write-Host "Uninstall complete." -ForegroundColor Green
