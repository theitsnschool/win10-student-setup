#Requires -RunAsAdministrator

$RepoBase = "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main"
$TempDir  = "$env:TEMP\win10-student-setup"

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  win10-student-setup - Master Launcher" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "  [!] Please re-run PowerShell as Administrator." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
Set-ExecutionPolicy Bypass -Scope Process -Force

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

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  STEP 1/2 - Cleanup & Bloatware Removal" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
& "$TempDir\remove-bloatware.ps1"

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  STEP 2/2 - Installing Tools" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
& "$TempDir\install-tools.ps1"

Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  ALL DONE - Restart the machine now." -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  After restart:" -ForegroundColor Yellow
Write-Host "  1. Run Windows Update (security patches)" -ForegroundColor White
Write-Host "  2. Activate Microsoft Office with your institution account" -ForegroundColor White
Write-Host "  3. Install Packet Tracer from netacad.com" -ForegroundColor White
Write-Host "  4. Install SageMath from sagemath.org if winget failed" -ForegroundColor White
Write-Host "  5. Open MSYS2 and run: pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb" -ForegroundColor White
Write-Host ""