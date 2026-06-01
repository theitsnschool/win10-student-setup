#Requires -RunAsAdministrator

$ProgressPreference   = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message, [string]$Color = "Green")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Winget {
    try { $null = winget --version 2>$null; return $true }
    catch { return $false }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1 - Microsoft Office Installation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Step "[1/2] Checking winget..."
if (-not (Test-Winget)) {
    Write-Host "  [!] winget not found. Run install-tools.ps1 first." -ForegroundColor Red
    exit 1
}
Write-Host "  [+] winget found: $(winget --version)" -ForegroundColor Green

Write-Host ""
Write-Step "[2/2] Installing Microsoft 365..."
Write-Host "  [>] Downloading Microsoft 365 (this may take a while)..." -ForegroundColor Yellow

$result = & winget install `
    --id Microsoft.Office `
    --source winget `
    --silent `
    --accept-package-agreements `
    --accept-source-agreements `
    --disable-interactivity `
    2>&1

$resultText = $result -join " "

if ($LASTEXITCODE -eq 0) {
    Write-Host "  [+] Microsoft 365 installed successfully." -ForegroundColor Green
} elseif ($resultText -match "already installed") {
    Write-Host "  [=] Microsoft 365 is already installed." -ForegroundColor DarkGray
} else {
    Write-Host "  [!] Microsoft 365 install failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    Write-Host "      Download manually: https://www.microsoft.com/en-us/microsoft-365" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Continuing to activation step..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2 - Activation (Windows + Office)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "  [i] Running Microsoft Activation Scripts (MAS) from massgrave.dev" -ForegroundColor Cyan
Write-Host "  [i] This will open an interactive menu to activate Windows and Office." -ForegroundColor Cyan
Write-Host ""
Write-Host "  In the menu, select:" -ForegroundColor Yellow
Write-Host "    [1] HWID - for Windows activation (permanent)" -ForegroundColor White
Write-Host "    [2] Ohook - for Office activation (permanent)" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to launch the activation script"

try {
    irm https://get.activated.win | iex
} catch {
    Write-Host ""
    Write-Host "  [!] Could not reach get.activated.win. Trying fallback..." -ForegroundColor DarkYellow
    try {
        irm https://massgrave.dev/get | iex
    } catch {
        Write-Host "  [!] Both activation URLs failed. Check your internet connection." -ForegroundColor Red
        Write-Host "      Manual: https://massgrave.dev" -ForegroundColor DarkGray
        exit 1
    }
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  [DONE] Office installation and activation complete." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Cyan
Write-Host "  - Open any Office app and sign in with your institution account" -ForegroundColor White
Write-Host "  - Run Windows Update to get the latest Office patches" -ForegroundColor White
Write-Host "  - Restart the machine if prompted" -ForegroundColor White