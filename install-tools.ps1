#Requires -RunAsAdministrator

$InstallSageMath     = $true
$InstallPacketTracer = $false
$InstallOffice       = $false
$VerboseOutput       = $true

function Install-App {
    param(
        [string]$Name,
        [string]$WingetId
    )
    if ($VerboseOutput) { Write-Host "  [>] Installing: $Name" -ForegroundColor Yellow }
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
        Write-Host "  [!] Failed: $Name (ID: $WingetId)" -ForegroundColor Red
        $result | Where-Object { $_ -match "error|failed|blocked|0x" } |
            ForEach-Object { Write-Host "      >> $_" -ForegroundColor DarkRed }
    }
}

function Test-Winget {
    try { winget --version 2>$null | Out-Null; return $true }
    catch { return $false }
}

function Install-Winget {
    Write-Host ""
    Write-Host "  [>] winget not found. Bootstrapping winget (App Installer)..." -ForegroundColor Yellow

    $vcLibsUrl  = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
    $uiXamlUrl  = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
    $wingetUrl  = "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    $licenseUrl = "https://github.com/microsoft/winget-cli/releases/latest/download/58fd9e76a78a4462b4ade03a2edac57b_License1.xml"

    $tmpDir = "$env:TEMP\winget-bootstrap"
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    $vcLibsPath  = "$tmpDir\VCLibs.appx"
    $uiXamlPath  = "$tmpDir\UIXaml.appx"
    $msixPath    = "$tmpDir\winget.msixbundle"
    $licensePath = "$tmpDir\license.xml"

    Write-Host "  [>] Downloading dependencies..." -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $vcLibsUrl  -OutFile $vcLibsPath  -UseBasicParsing -ErrorAction Stop
        Invoke-WebRequest -Uri $uiXamlUrl  -OutFile $uiXamlPath  -UseBasicParsing -ErrorAction Stop
        Invoke-WebRequest -Uri $wingetUrl  -OutFile $msixPath    -UseBasicParsing -ErrorAction Stop
        Invoke-WebRequest -Uri $licenseUrl -OutFile $licensePath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  [!] Download failed: $_" -ForegroundColor Red
        Write-Host "      Install winget manually from the Microsoft Store (App Installer)." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "  [>] Installing VCLibs..." -ForegroundColor Yellow
    Add-AppxPackage -Path $vcLibsPath -ErrorAction SilentlyContinue

    Write-Host "  [>] Installing Microsoft.UI.Xaml..." -ForegroundColor Yellow
    Add-AppxPackage -Path $uiXamlPath -ErrorAction SilentlyContinue

    Write-Host "  [>] Installing winget (App Installer)..." -ForegroundColor Yellow
    Add-AppxProvisionedPackage -Online -PackagePath $msixPath -LicensePath $licensePath -ErrorAction Stop | Out-Null

    Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    if (Test-Winget) {
        Write-Host "  [+] winget installed successfully: $(winget --version)" -ForegroundColor Green
    } else {
        Write-Host "  [!] winget still not available. A reboot may be required before continuing." -ForegroundColor Red
        exit 1
    }
}

function Install-RequiredTools {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  PHASE 1 - Bootstrap: winget + Core Toolchain" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan

    Write-Host ""
    Write-Host "[BOOTSTRAP 1/3] Checking winget..." -ForegroundColor Green
    if (-not (Test-Winget)) {
        Install-Winget
    } else {
        Write-Host "  [+] winget found: $(winget --version)" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "[BOOTSTRAP 2/3] Refreshing winget sources..." -ForegroundColor Green
    winget source update --disable-interactivity 2>&1 | Out-Null
    Write-Host "  [+] Sources refreshed" -ForegroundColor Green

    Write-Host ""
    Write-Host "[BOOTSTRAP 3/3] Installing prerequisite tools..." -ForegroundColor Green
    Install-App "Microsoft Visual C++ Redistributable x64" "Microsoft.VCRedist.2015+.x64"
    Install-App "Microsoft Visual C++ Redistributable x86" "Microsoft.VCRedist.2015+.x86"
    Install-App "PowerShell 7"                             "Microsoft.PowerShell"
    Install-App "Windows Terminal"                         "Microsoft.WindowsTerminal"
    Install-App "Git for Windows"                          "Git.Git"

    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")

    Write-Host ""
    Write-Host "  [+] Bootstrap complete. Proceeding with main installs." -ForegroundColor Green
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  win10-student-setup - Tool Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Install-RequiredTools

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2 - Main Software Installation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "[1/7] Installing browsers..." -ForegroundColor Green
Install-App "Mozilla Firefox"  "Mozilla.Firefox"
Install-App "Google Chrome"    "Google.Chrome"

Write-Host ""
Write-Host "[2/7] Installing core dev tools..." -ForegroundColor Green
Install-App "Visual Studio Code"  "Microsoft.VisualStudioCode"
Install-App "Python 3.12"         "Python.Python.3.12"
Install-App "Node.js LTS"         "OpenJS.NodeJS.LTS"

Write-Host ""
Write-Host "[3/7] Installing Java JDK 21..." -ForegroundColor Green
Install-App "Eclipse Temurin JDK 21 (LTS)" "EclipseAdoptium.Temurin.21.JDK"

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

Write-Host ""
Write-Host "[4/7] Installing C/C++ tools..." -ForegroundColor Green
Install-App "Dev-C++ (Embarcadero)" "Embarcadero.Dev-Cpp"
Install-App "MSYS2 (GCC/MinGW toolchain)" "MSYS2.MSYS2"
Write-Host "  [i] After MSYS2 installs, open MSYS2 terminal and run:" -ForegroundColor Cyan
Write-Host "      pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb" -ForegroundColor DarkGray

Write-Host ""
Write-Host "[5/7] Installing PHP environment (XAMPP)..." -ForegroundColor Green
Install-App "XAMPP 8.2" "ApacheFriends.Xampp.8.2"
Write-Host "  [i] XAMPP installs to C:\xampp - use XAMPP Control Panel to start Apache/MySQL" -ForegroundColor Cyan

Write-Host ""
Write-Host "[6/7] Installing productivity & utilities..." -ForegroundColor Green
Install-App "7-Zip"       "7zip.7zip"
Install-App "VLC"         "VideoLAN.VLC"
Install-App "Notepad++"   "Notepad++.Notepad++"

Write-Host ""
Write-Host "[7/7] Optional tools..." -ForegroundColor Green

if ($InstallSageMath) {
    Write-Host "  [>] Installing SageMath (large download ~1GB, please wait)..." -ForegroundColor Yellow
    Install-App "SageMath" "sagemath.sagemath"
    Write-Host "  [i] If SageMath fails: https://www.sagemath.org/download-windows.html" -ForegroundColor Cyan
} else {
    Write-Host "  [=] Skipping SageMath (set InstallSageMath=true to enable)" -ForegroundColor DarkGray
    Write-Host "      Manual: https://www.sagemath.org/download-windows.html" -ForegroundColor DarkGray
}

if ($InstallPacketTracer) {
    Write-Host "  [i] Packet Tracer requires a free Cisco NetAcad account." -ForegroundColor Cyan
    Write-Host "      Download: https://www.netacad.com/resources/lab-downloads" -ForegroundColor DarkGray
    Write-Host "      1. Create account at netacad.com" -ForegroundColor DarkGray
    Write-Host "      2. Enroll in a free course (e.g. 'Introduction to Packet Tracer')" -ForegroundColor DarkGray
    Write-Host "      3. Download Packet Tracer from your course resources" -ForegroundColor DarkGray
} else {
    Write-Host "  [=] Skipping Packet Tracer (set InstallPacketTracer=true for instructions)" -ForegroundColor DarkGray
}

if ($InstallOffice) {
    Write-Host "  [>] Launching Microsoft Office installer..." -ForegroundColor Yellow
    Install-App "Microsoft 365" "Microsoft.Office"
    Write-Host "  [i] Sign in with your institution Microsoft account to activate." -ForegroundColor Cyan
} else {
    Write-Host "  [=] Skipping Office (set InstallOffice=true to enable)" -ForegroundColor DarkGray
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 3 - Post-Install Configuration" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "Configuring Git defaults..." -ForegroundColor Cyan
$gitExe = Get-Command git -ErrorAction SilentlyContinue
if ($gitExe) {
    git config --global core.autocrlf true
    git config --global init.defaultBranch main
    git config --global core.editor "code --wait"
    Write-Host "  [+] Git configured (autocrlf=true, defaultBranch=main, editor=vscode)" -ForegroundColor Green
} else {
    Write-Host "  [!] Git not in PATH yet - run after reboot:" -ForegroundColor DarkYellow
    Write-Host "      git config --global core.autocrlf true" -ForegroundColor DarkGray
    Write-Host "      git config --global init.defaultBranch main" -ForegroundColor DarkGray
    Write-Host "      git config --global core.editor `"code --wait`"" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "Installing common Python packages..." -ForegroundColor Cyan
$pythonExe = Get-Command python -ErrorAction SilentlyContinue
if ($pythonExe) {
    $pipPackages = @("pip", "requests", "numpy", "matplotlib", "pandas")
    foreach ($pkg in $pipPackages) {
        python -m pip install --upgrade $pkg --quiet 2>&1 | Out-Null
        Write-Host "  [+] pip: $pkg" -ForegroundColor Green
    }
} else {
    Write-Host "  [!] Python not in PATH yet - pip packages will need to be installed after reboot." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "Installing VS Code extensions..." -ForegroundColor Cyan
$codeExe = Get-Command code -ErrorAction SilentlyContinue
if ($codeExe) {
    $extensions = @(
        "ms-python.python",
        "ms-python.debugpy",
        "vscjava.vscode-java-pack",
        "ms-vscode.cpptools",
        "bmewburn.vscode-intelephense-client",
        "ritwickdey.LiveServer",
        "esbenp.prettier-vscode",
        "eamodio.gitlens",
        "ms-vscode.powershell"
    )
    foreach ($ext in $extensions) {
        code --install-extension $ext --force 2>&1 | Out-Null
        Write-Host "  [+] VS Code: $ext" -ForegroundColor Green
    }
} else {
    Write-Host "  [!] VS Code not in PATH yet - extensions will need to be installed after reboot." -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "  [DONE] Tool installation complete." -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Installed:" -ForegroundColor Cyan
Write-Host "  Bootstrap  : winget, VCRedist, PowerShell 7, Windows Terminal, Git" -ForegroundColor White
Write-Host "  Browsers   : Firefox, Chrome" -ForegroundColor White
Write-Host "  Dev tools  : VS Code, Python 3.12, Node.js, Java JDK 21" -ForegroundColor White
Write-Host "  C/C++      : Dev-C++, MSYS2/MinGW" -ForegroundColor White
Write-Host "  PHP        : XAMPP (Apache + PHP + MySQL)" -ForegroundColor White
Write-Host "  Utilities  : 7-Zip, VLC, Notepad++" -ForegroundColor White
Write-Host ""
Write-Host "  Manual installs still needed:" -ForegroundColor Yellow
Write-Host "  - Cisco Packet Tracer : https://www.netacad.com/resources/lab-downloads" -ForegroundColor DarkGray
Write-Host "  - SageMath (if failed): https://www.sagemath.org/download-windows.html" -ForegroundColor DarkGray
Write-Host "  - Microsoft Office    : requires institution license/account" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Restart the machine to apply all PATH and registry changes." -ForegroundColor Yellow