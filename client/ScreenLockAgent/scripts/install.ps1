#Requires -RunAsAdministrator

<#
.SYNOPSIS
  Installs the Screen Lock Agent on this Windows PC.

.DESCRIPTION
  Downloads the latest release from GitHub (or uses a local folder),
  copies files to Program Files, creates a logon scheduled task, and starts the agent.

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

function Write-Step($Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
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

    Write-Step "Registering scheduled task ($TaskName)"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

    $action = New-ScheduledTaskAction -Execute "$InstallPath\ScreenLockAgent.exe" -WorkingDirectory $InstallPath
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -GroupId "BUILTIN\Users" -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "iCodeSchool classroom screen lock agent" | Out-Null

    Write-Step "Starting agent"
    Start-Process -FilePath "$InstallPath\ScreenLockAgent.exe" -WorkingDirectory $InstallPath

    Write-Host ""
    Write-Host "Install complete." -ForegroundColor Green
    Write-Host "Agent path: $InstallPath\ScreenLockAgent.exe"
    Write-Host "The agent will also start automatically at user logon."
    Write-Host "Check the admin dashboard for this device: https://icodeschool-eight.vercel.app"
}

if ($LocalPath -ne "") {
    Install-FromDirectory (Resolve-Path $LocalPath)
    exit 0
}

Write-Step "Fetching latest release from $Repo"
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers @{ "User-Agent" = "ScreenLockAgent-Installer" }
$asset = $release.assets | Where-Object { $_.name -eq "ScreenLockAgent-win-x64.zip" } | Select-Object -First 1

if (-not $asset) {
    throw "No ScreenLockAgent-win-x64.zip found in latest release. Run the 'Build & Release Windows Agent' workflow on GitHub first."
}

$tempRoot = Join-Path $env:TEMP "ScreenLockAgent-install"
$zipPath = Join-Path $tempRoot "ScreenLockAgent-win-x64.zip"
$extractPath = Join-Path $tempRoot "extracted"

Write-Step "Downloading $($asset.name)"
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

Write-Step "Extracting"
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

Install-FromDirectory $extractPath
