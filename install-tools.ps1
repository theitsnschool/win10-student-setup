#Requires -RunAsAdministrator

$InstallPacketTracer = $false
$VerboseOutput       = $true

$ProgressPreference  = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

$script:InstallLog = [System.Collections.Generic.List[string]]::new()
$script:FailedApps = [System.Collections.Generic.List[string]]::new()

function Write-Step {
    param([string]$Message, [string]$Color = "Green")
    Write-Host $Message -ForegroundColor $Color
}

function Install-App {
    param(
        [string]$Name,
        [string]$WingetId,
        [string[]]$ExtraArgs = @()
    )
    if ($VerboseOutput) { Write-Host "  [>] Installing: $Name" -ForegroundColor Yellow }

    $args = @(
        "install", "--id", $WingetId,
        "--source", "winget",
        "--silent",
        "--accept-package-agreements",
        "--accept-source-agreements",
        "--disable-interactivity"
    ) + $ExtraArgs

    $result = & winget @args 2>&1
    $resultText = $result -join " "

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] Installed: $Name" -ForegroundColor Green
        $script:InstallLog.Add("[OK]  $Name")
    } elseif ($LASTEXITCODE -eq -1978335189 -or $resultText -match "already installed|No applicable upgrade") {
        Write-Host "  [=] Already installed: $Name" -ForegroundColor DarkGray
        $script:InstallLog.Add("[==] $Name (already present)")
    } else {
        Write-Host "  [!] Failed: $Name (ID: $WingetId) - exit code $LASTEXITCODE" -ForegroundColor Red
        $result | Where-Object { $_ -match "error|failed|blocked|0x" } |
            ForEach-Object { Write-Host "      >> $_" -ForegroundColor DarkRed }
        $script:FailedApps.Add("$Name ($WingetId)")
        $script:InstallLog.Add("[!!] $Name - FAILED")
    }
}

function Test-Winget {
    try { $null = winget --version 2>$null; return $true }
    catch { return $false }
}

function Install-Winget {
    Write-Host ""
    Write-Host "  [>] winget not found. Bootstrapping winget (App Installer)..." -ForegroundColor Yellow

    $tmpDir      = "$env:TEMP\winget-bootstrap"
    $vcLibsPath  = "$tmpDir\VCLibs.appx"
    $uiXamlPath  = "$tmpDir\UIXaml.appx"
    $msixPath    = "$tmpDir\winget.msixbundle"
    $licensePath = "$tmpDir\license.xml"

    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    Write-Host "  [>] Resolving latest winget release from GitHub..." -ForegroundColor Yellow
    try {
        $release    = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-cli/releases/latest" -UseBasicParsing -ErrorAction Stop
        $msixUrl    = ($release.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1).browser_download_url
        $licenseUrl = ($release.assets | Where-Object { $_.name -like "*License1.xml" } | Select-Object -First 1).browser_download_url
        if (-not $msixUrl -or -not $licenseUrl) { throw "Could not find required assets in release." }
        Write-Host "  [+] Found winget $($release.tag_name)" -ForegroundColor Green
    } catch {
        Write-Host "  [!] GitHub API failed: $_" -ForegroundColor Red
        Write-Host "      Falling back to known stable release (v1.28.240)..." -ForegroundColor DarkYellow
        $msixUrl    = "https://github.com/microsoft/winget-cli/releases/download/v1.28.240/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $licenseUrl = "https://github.com/microsoft/winget-cli/releases/download/v1.28.240/d7e5d3f83aea470a864caef75e32f8e3_License1.xml"
    }

    $downloads = [ordered]@{
        $vcLibsPath  = "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx"
        $uiXamlPath  = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx"
        $msixPath    = $msixUrl
        $licensePath = $licenseUrl
    }

    Write-Host "  [>] Downloading dependencies..." -ForegroundColor Yellow
    foreach ($dest in $downloads.Keys) {
        try {
            Invoke-WebRequest -Uri $downloads[$dest] -OutFile $dest -UseBasicParsing -ErrorAction Stop
        } catch {
            Write-Host "  [!] Download failed: $_" -ForegroundColor Red
            Write-Host "      Install winget manually from the Microsoft Store (App Installer)." -ForegroundColor Yellow
            exit 1
        }
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

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Set-JavaHome {
    $javaPath = "C:\Program Files\Eclipse Adoptium\jdk-21*"
    $found = Get-Item $javaPath -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        [System.Environment]::SetEnvironmentVariable("JAVA_HOME", $found.FullName, "Machine")
        $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
        if ($machinePath -notlike "*$($found.FullName)*") {
            [System.Environment]::SetEnvironmentVariable("Path", "$machinePath;$($found.FullName)\bin", "Machine")
        }
        $env:JAVA_HOME = $found.FullName
        Write-Host "  [+] JAVA_HOME set to: $($found.FullName)" -ForegroundColor Green
    } else {
        Write-Host "  [!] JDK path not found - set JAVA_HOME manually after reboot." -ForegroundColor DarkYellow
    }
}

function Configure-Git {
    Refresh-Path
    $gitExe = Get-Command git -ErrorAction SilentlyContinue
    if ($gitExe) {
        $gitConfigs = @{
            "core.autocrlf"      = "true"
            "init.defaultBranch" = "main"
            "core.editor"        = "code --wait"
            "core.longpaths"     = "true"
            "pull.rebase"        = "false"
        }
        foreach ($key in $gitConfigs.Keys) {
            git config --global $key $gitConfigs[$key]
        }
        Write-Host "  [+] Git configured (autocrlf, defaultBranch=main, editor=vscode, longpaths)" -ForegroundColor Green
    } else {
        Write-Host "  [!] Git not in PATH yet - run after reboot:" -ForegroundColor DarkYellow
        Write-Host "      git config --global core.autocrlf true" -ForegroundColor DarkGray
        Write-Host "      git config --global init.defaultBranch main" -ForegroundColor DarkGray
        Write-Host "      git config --global core.editor `"code --wait`"" -ForegroundColor DarkGray
        Write-Host "      git config --global core.longpaths true" -ForegroundColor DarkGray
        Write-Host "      git config --global pull.rebase false" -ForegroundColor DarkGray
    }
}

function Install-PipPackages {
    Refresh-Path
    $pythonExe = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonExe) {
        python -m pip install --upgrade pip --quiet 2>&1 | Out-Null
        $pipPackages = @("requests", "numpy", "matplotlib", "pandas", "virtualenv")
        foreach ($pkg in $pipPackages) {
            $out = python -m pip install --upgrade $pkg --quiet 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [+] pip: $pkg" -ForegroundColor Green
            } else {
                Write-Host "  [!] pip failed: $pkg" -ForegroundColor DarkYellow
            }
        }
    } else {
        Write-Host "  [!] Python not in PATH yet - pip packages will need to be installed after reboot." -ForegroundColor DarkYellow
    }
}

function Install-VSCodeExtensions {
    Refresh-Path
    $codeExe = Get-Command code -ErrorAction SilentlyContinue
    if ($codeExe) {
        $extensions = @(
            "ms-python.python",
            "ms-python.debugpy",
            "ms-python.pylint",
            "vscjava.vscode-java-pack",
            "ms-vscode.cpptools",
            "ms-vscode.cpptools-extension-pack",
            "bmewburn.vscode-intelephense-client",
            "ritwickdey.LiveServer",
            "esbenp.prettier-vscode",
            "eamodio.gitlens",
            "ms-vscode.powershell",
            "formulahendry.code-runner",
            "streetsidesoftware.code-spell-checker"
        )
        foreach ($ext in $extensions) {
            $out = code --install-extension $ext --force 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [+] VS Code ext: $ext" -ForegroundColor Green
            } else {
                Write-Host "  [!] VS Code ext failed: $ext" -ForegroundColor DarkYellow
            }
        }
    } else {
        Write-Host "  [!] VS Code not in PATH yet - extensions will need to be installed after reboot." -ForegroundColor DarkYellow
    }
}

function Print-Summary {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Cyan
    Write-Host "  INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "================================================" -ForegroundColor Cyan

    foreach ($entry in $script:InstallLog) {
        $color = if ($entry -match "^\[!!\]") { "Red" } elseif ($entry -match "^\[==\]") { "DarkGray" } else { "Green" }
        Write-Host "  $entry" -ForegroundColor $color
    }

    if ($script:FailedApps.Count -gt 0) {
        Write-Host ""
        Write-Host "  Failed installs ($($script:FailedApps.Count)):" -ForegroundColor Red
        foreach ($app in $script:FailedApps) {
            Write-Host "    - $app" -ForegroundColor DarkRed
        }
        Write-Host ""
        Write-Host "  Tip: Run 'winget source update' then retry the script for failed apps." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  Manual steps still needed:" -ForegroundColor Yellow
    if ($InstallPacketTracer) {
        Write-Host "  - Cisco Packet Tracer : https://www.netacad.com/resources/lab-downloads" -ForegroundColor DarkGray
    }
    Write-Host "  - MSYS2 GCC           : open MSYS2 terminal and run:" -ForegroundColor DarkGray
    Write-Host "      pacman -Syu && pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb mingw-w64-x86_64-make" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Restart the machine to apply all PATH and registry changes." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  win10-student-setup - Tool Installer" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1 - Bootstrap: winget + Core Toolchain" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Step "[BOOTSTRAP 1/3] Checking winget..."
if (-not (Test-Winget)) {
    Install-Winget
} else {
    Write-Host "  [+] winget found: $(winget --version)" -ForegroundColor Green
}

Write-Host ""
Write-Step "[BOOTSTRAP 2/3] Refreshing winget sources..."
winget source update --disable-interactivity 2>&1 | Out-Null
Write-Host "  [+] Sources refreshed" -ForegroundColor Green

Write-Host ""
Write-Step "[BOOTSTRAP 3/3] Installing prerequisite tools..."
Install-App "Microsoft Visual C++ Redistributable x64" "Microsoft.VCRedist.2015+.x64"
Install-App "Microsoft Visual C++ Redistributable x86" "Microsoft.VCRedist.2015+.x86"
Install-App "PowerShell 7"                             "Microsoft.PowerShell"
Install-App "Windows Terminal"                         "Microsoft.WindowsTerminal"
Install-App "Git for Windows"                          "Git.Git"
Refresh-Path

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2 - Main Software Installation" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Step "[1/7] Installing browsers..."
Install-App "Mozilla Firefox" "Mozilla.Firefox"
Install-App "Google Chrome"   "Google.Chrome"

Write-Host ""
Write-Step "[2/7] Installing core dev tools..."
Install-App "Visual Studio Code" "Microsoft.VisualStudioCode"
Install-App "Python 3.12"        "Python.Python.3.12"
Install-App "Node.js LTS"        "OpenJS.NodeJS.LTS"

Write-Host ""
Write-Step "[3/7] Installing Java JDK 21..."
Install-App "Eclipse Temurin JDK 21 (LTS)" "EclipseAdoptium.Temurin.21.JDK"
Set-JavaHome

Write-Host ""
Write-Step "[4/7] Installing C/C++ tools..."
Install-App "Dev-C++ (Embarcadero)" "Embarcadero.Dev-C++"
Install-App "MSYS2 (GCC/MinGW toolchain)" "MSYS2.MSYS2"
Write-Host "  [i] After MSYS2 installs, open MSYS2 terminal and run:" -ForegroundColor Cyan
Write-Host "      pacman -Syu && pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb mingw-w64-x86_64-make" -ForegroundColor DarkGray

Write-Host ""
Write-Step "[5/7] Installing PHP environment (XAMPP)..."
Install-App "XAMPP 8.2" "ApacheFriends.Xampp.8.2"
Write-Host "  [i] XAMPP installs to C:\xampp - use XAMPP Control Panel to start Apache/MySQL" -ForegroundColor Cyan

Write-Host ""
Write-Step "[6/7] Installing productivity and utilities..."
Install-App "7-Zip"     "7zip.7zip"
Install-App "VLC"       "VideoLAN.VLC"
Install-App "Notepad++" "Notepad++.Notepad++"

Write-Host ""
Write-Step "[7/7] Optional tools..."

if ($InstallPacketTracer) {
    Write-Host "  [i] Packet Tracer requires a free Cisco NetAcad account." -ForegroundColor Cyan
    Write-Host "      1. Create account at https://www.netacad.com" -ForegroundColor DarkGray
    Write-Host "      2. Enroll in a free course (e.g. 'Introduction to Packet Tracer')" -ForegroundColor DarkGray
    Write-Host "      3. Download Packet Tracer from your course resources" -ForegroundColor DarkGray
} else {
    Write-Host "  [=] Skipping Packet Tracer (set InstallPacketTracer=true for instructions)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 3 - Post-Install Configuration" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Step "Configuring Git..."
Configure-Git

Write-Host ""
Write-Step "Installing common Python packages..."
Install-PipPackages

Write-Host ""
Write-Step "Installing VS Code extensions..."
Install-VSCodeExtensions

Print-Summary