#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installs all needed tools for a Windows 10 student dev/office machine.
.DESCRIPTION
    Uses winget (Windows Package Manager) to install dev tools, browsers,
    and productivity apps. Covers: Python, Java, C/C++, PHP, Git, VS Code,
    Firefox, Chrome, VLC, 7-Zip, Notepad++, Node.js, XAMPP.
.NOTES
    Run AFTER 1-Remove-Bloatware.ps1 and a system restart.
    Requires internet connection.
#>

# ---------------------------------------------
# CONFIGURATION
# ---------------------------------------------
$InstallSageMath     = $true    # Large download (~1GB) - set $false to skip
$InstallPacketTracer = $false   # Requires Cisco NetAcad account - set $true to download
$InstallOffice       = $false   # Requires license - set $true to launch installer
$VerboseOutput       = $true

# ---------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------
function Install-App {
    param(
        [string]$Name,
        [string]$WingetId,
        [string]$Category = ""
    )
    if ($VerboseOutput) { Write-Host "  [>] Installing: $Name" -ForegroundColor Yellow }

    # --source winget skips the broken msstore source
    # --silent suppresses UI, but we keep interactivity ON so winget can make decisions
    $result = winget install --id $WingetId `
        --source winget `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements `
        2>&1

    $resultText = $result -join " "

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] Installed: $Name" -ForegroundColor Green
    } elseif ($resultText -match "already installed" -or $resultText -match "No applicable upgrade") {
        Write-Host "  [=] Already installed: $Name" -ForegroundColor DarkGray
    } else {
        Write-Host "  [!] Failed: $Name" -ForegroundColor Red
        # Print the actual winget error so we can diagnose it
        $result | Where-Object { $_ -match "error|failed|blocked|0x" } |
            ForEach-Object { Write-Host "      >> $_" -ForegroundColor DarkRed }
        Write-Host "      Winget ID: $WingetId" -ForegroundColor DarkGray
    }
}

function Test-Winget {
    try {
        $ver = winget --version 2>$null
        return $true
    } catch {
        return $false
    }
}

# ---------------------------------------------
# PREFLIGHT: Check winget is available
# ---------------------------------------------
Write-Host ""
Write-Host "Checking winget availability..." -ForegroundColor Cyan
if (-not (Test-Winget)) {
    Write-Host ""
    Write-Host "  [!] winget not found." -ForegroundColor Red
    Write-Host "      Fix: Open Microsoft Store, search 'App Installer', click Update." -ForegroundColor Yellow
    Write-Host "      Then re-run this script." -ForegroundColor Yellow
    exit 1
}
Write-Host "  [+] winget found: $(winget --version)" -ForegroundColor Green

# Update winget sources
Write-Host "  [>] Refreshing winget sources..." -ForegroundColor DarkGray
winget source update --disable-interactivity 2>&1 | Out-Null

# ---------------------------------------------
# 1. BROWSERS
# ---------------------------------------------
Write-Host ""
Write-Host "[1/7] Installing browsers..." -ForegroundColor Green
Install-App "Mozilla Firefox"  "Mozilla.Firefox"
Install-App "Google Chrome"    "Google.Chrome"

# ---------------------------------------------
# 2. DEV TOOLS - CORE
# ---------------------------------------------
Write-Host ""
Write-Host "[2/7] Installing core dev tools..." -ForegroundColor Green
Install-App "Git for Windows"       "Git.Git"
Install-App "Visual Studio Code"    "Microsoft.VisualStudioCode"
Install-App "Python 3"              "Python.Python.3.12"
Install-App "Node.js LTS"           "OpenJS.NodeJS.LTS"

# ---------------------------------------------
# 3. JAVA
# ---------------------------------------------
Write-Host ""
Write-Host "[3/7] Installing Java JDK..." -ForegroundColor Green
Install-App "Eclipse Temurin JDK 21 (LTS)" "EclipseAdoptium.Temurin.21.JDK"

# Verify JAVA_HOME after install
$javaPath = "C:\Program Files\Eclipse Adoptium\jdk-21*"
$found = Get-Item $javaPath -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) {
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $found.FullName, "Machine")
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($currentPath -notlike "*$($found.FullName)*") {
        [System.Environment]::SetEnvironmentVariable("Path", "$currentPath;$($found.FullName)\bin", "Machine")
    }
    Write-Host "  [+] JAVA_HOME set to: $($found.FullName)" -ForegroundColor Green
}

# ---------------------------------------------
# 4. C / C++ - Dev-C++
# ---------------------------------------------
Write-Host ""
Write-Host "[4/7] Installing C/C++ tools..." -ForegroundColor Green
# Try winget first, fall back to direct installer info
Install-App "Dev-C++ (Embarcadero)" "Embarcadero.Dev-Cpp"

# Also install MinGW-w64 (GCC for Windows) as compiler backend
Install-App "MSYS2 (GCC/MinGW toolchain)" "MSYS2.MSYS2"
Write-Host "  [i] After MSYS2 installs, run in MSYS2 terminal:" -ForegroundColor Cyan
Write-Host "      pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb" -ForegroundColor DarkGray

# ---------------------------------------------
# 5. PHP - XAMPP (Apache + PHP + MySQL)
# ---------------------------------------------
Write-Host ""
Write-Host "[5/7] Installing PHP environment (XAMPP)..." -ForegroundColor Green
Install-App "XAMPP" "ApacheFriends.Xampp.8.2"
Write-Host "  [i] XAMPP installs to C:\xampp - start Apache and MySQL from the XAMPP Control Panel" -ForegroundColor Cyan

# ---------------------------------------------
# 6. PRODUCTIVITY & UTILITIES
# ---------------------------------------------
Write-Host ""
Write-Host "[6/7] Installing productivity tools..." -ForegroundColor Green
Install-App "7-Zip"        "7zip.7zip"
Install-App "VLC"          "VideoLAN.VLC"
Install-App "Notepad++"    "Notepad++.Notepad++"

# ---------------------------------------------
# 7. OPTIONAL: SAGEMATH, PACKET TRACER, OFFICE
# ---------------------------------------------
Write-Host ""
Write-Host "[7/7] Optional tools..." -ForegroundColor Green

if ($InstallSageMath) {
    Write-Host "  [>] Installing SageMath (large download, please wait)..." -ForegroundColor Yellow
    Install-App "SageMath" "sagemath.sagemath"
    Write-Host "  [i] If SageMath fails via winget, download from: https://www.sagemath.org/download-windows.html" -ForegroundColor Cyan
} else {
    Write-Host "  [=] Skipping SageMath (set InstallSageMath to true to enable)" -ForegroundColor DarkGray
    Write-Host "      Manual download: https://www.sagemath.org/download-windows.html" -ForegroundColor DarkGray
}

if ($InstallPacketTracer) {
    Write-Host "  [i] Packet Tracer requires a free Cisco NetAcad account." -ForegroundColor Cyan
    Write-Host "      Download from: https://www.netacad.com/resources/lab-downloads" -ForegroundColor DarkGray
    Write-Host "      1. Create a free account at netacad.com" -ForegroundColor DarkGray
    Write-Host "      2. Enroll in any free course (e.g. 'Introduction to Packet Tracer')" -ForegroundColor DarkGray
    Write-Host "      3. Download and install Packet Tracer from your course resources" -ForegroundColor DarkGray
} else {
    Write-Host "  [=] Skipping Packet Tracer (set InstallPacketTracer to true for instructions)" -ForegroundColor DarkGray
}

if ($InstallOffice) {
    Write-Host "  [>] Launching Microsoft Office installer..." -ForegroundColor Yellow
    Install-App "Microsoft 365" "Microsoft.Office"
    Write-Host "  [i] Sign in with your institution Microsoft account to activate." -ForegroundColor Cyan
} else {
    Write-Host "  [=] Skipping Office (set InstallOffice to true to enable)" -ForegroundColor DarkGray
}

# ---------------------------------------------
# REFRESH PATH (picks up newly installed tools)
# ---------------------------------------------
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

# ---------------------------------------------
# CONFIGURE GIT GLOBAL DEFAULTS
# ---------------------------------------------
Write-Host ""
Write-Host "Configuring Git defaults..." -ForegroundColor Cyan
$gitExe = Get-Command git -ErrorAction SilentlyContinue
if ($gitExe) {
    git config --global core.autocrlf true
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    Write-Host "  [+] Git configured (autocrlf=true, defaultBranch=main, editor=vscode)" -ForegroundColor Green
} else {
    Write-Host "  [!] Git not found in PATH yet -- config will apply after restart." -ForegroundColor DarkYellow
    Write-Host "      Run this after reboot: git config --global core.autocrlf true" -ForegroundColor DarkGray
    Write-Host "                             git config --global init.defaultBranch main" -ForegroundColor DarkGray
    Write-Host "                             git config --global core.editor code --wait" -ForegroundColor DarkGray
}

# ---------------------------------------------
# INSTALL PYTHON PACKAGES
# ---------------------------------------------
Write-Host ""
Write-Host "Installing common Python packages..." -ForegroundColor Cyan
$pipPackages = @("pip", "requests", "numpy", "matplotlib")
foreach ($pkg in $pipPackages) {
    python -m pip install --upgrade $pkg --quiet 2>&1 | Out-Null
    Write-Host "  [+] pip: $pkg" -ForegroundColor Green
}

# ---------------------------------------------
# INSTALL VS CODE EXTENSIONS
# ---------------------------------------------
Write-Host ""
Write-Host "Installing VS Code extensions..." -ForegroundColor Cyan
$extensions = @(
    "ms-python.python",            # Python
    "ms-python.debugpy",           # Python debugger
    "vscjava.vscode-java-pack",    # Java extension pack
    "ms-vscode.cpptools",          # C/C++
    "bmewburn.vscode-intelephense-client",  # PHP
    "ritwickdey.LiveServer",        # Live Server for web dev
    "esbenp.prettier-vscode",       # Prettier formatter
    "GitLens"                       # Git tools
)
foreach ($ext in $extensions) {
    code --install-extension $ext --force 2>&1 | Out-Null
    Write-Host "  [+] VS Code: $ext" -ForegroundColor Green
}

# ---------------------------------------------
# SUMMARY
# ---------------------------------------------
Write-Host ""
Write-Host "  [DONE] Tool installation complete." -ForegroundColor Green
Write-Host ""
Write-Host "  Installed:" -ForegroundColor Cyan
Write-Host "    Browsers   : Firefox, Chrome" -ForegroundColor White
Write-Host "    Dev tools  : Git, VS Code, Python 3, Node.js, Java JDK 21" -ForegroundColor White
Write-Host "    C/C++      : Dev-C++, MSYS2/MinGW" -ForegroundColor White
Write-Host "    PHP        : XAMPP (Apache + PHP + MySQL)" -ForegroundColor White
Write-Host "    Utilities  : 7-Zip, VLC, Notepad++" -ForegroundColor White
Write-Host ""
Write-Host "  Manual installs still needed:" -ForegroundColor Yellow
Write-Host "    - Cisco Packet Tracer : https://www.netacad.com/resources/lab-downloads" -ForegroundColor DarkGray
Write-Host "    - SageMath (if failed): https://www.sagemath.org/download-windows.html" -ForegroundColor DarkGray
Write-Host "    - Microsoft Office    : requires institution license/account" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Restart recommended to apply PATH changes." -ForegroundColor Yellow