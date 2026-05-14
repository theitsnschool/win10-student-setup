#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Master launcher for win10-student-setup.
    Downloads and runs all setup scripts in the correct order.
.NOTES
    Run this on a fresh Windows 10 install with internet connected.
    Usage: irm https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/Run-All.ps1 | iex
#>

$RepoBase = "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main"
$TempDir  = "$env:TEMP\win10-student-setup"

# ---------------------------------------------
# PREFLIGHT
# ---------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  win10-student-setup - Master Launcher" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [!] Please re-run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

# Create temp dir
New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Set-ExecutionPolicy Bypass -Scope Process -Force

# ---------------------------------------------
# DOWNLOAD SCRIPTS
# ---------------------------------------------
Write-Host "Downloading scripts from GitHub..." -ForegroundColor Cyan
$scripts = @("remove-bloatware.ps1", "install-tools.ps1")

foreach ($script in $scripts) {
    $url  = "$RepoBase/$script"
    $dest = "$TempDir\$script"
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        Write-Host "  [+] Downloaded: $script" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Failed to download $script" -ForegroundColor Red
        Write-Host "      URL: $url" -ForegroundColor DarkGray
        exit 1
    }
}

# ---------------------------------------------
# STEP 1: REMOVE BLOATWARE
# ---------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  STEP 1/2 — Removing bloatware..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
& "$TempDir\remove-bloatware.ps1"

# ---------------------------------------------
# STEP 2: INSTALL TOOLS
# ---------------------------------------------
Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  STEP 2/2 — Installing tools..." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
& "$TempDir\install-tools.ps1"

# ---------------------------------------------
# CLEANUP & DONE
# ---------------------------------------------
Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  ALL DONE - Restart the machine now." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  After restart:" -ForegroundColor Yellow
Write-Host "  1. Run Windows Update (important for security)" -ForegroundColor White
Write-Host "  2. Activate Microsoft Office with your institution account" -ForegroundColor White
Write-Host "  3. Install Packet Tracer from netacad.com" -ForegroundColor White
Write-Host "  4. Install SageMath from sagemath.org if winget failed" -ForegroundColor White
Write-Host ""