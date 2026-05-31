# win10-student-setup

Automated Windows 10 cleanup and setup for student lab machines.

---

## Quick Start

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/run-all.ps1 | iex
```

That's it. The script cleans the system and installs all tools automatically.

---

## Download Scripts

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/remove-bloatware.ps1" -OutFile "remove-bloatware.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/install-tools.ps1" -OutFile "install-tools.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/run-all.ps1" -OutFile "run-all.ps1"
```

## Run Individual Scripts

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

# Cleanup only
.\remove-bloatware.ps1

# Install tools only
.\install-tools.ps1
```

---

## Configuration

Edit the flags at the top of each script before running:

```powershell
# remove-bloatware.ps1
$RemoveOneDrive = $false   # $true to remove OneDrive
$RemoveSkype    = $true    # $false to keep Skype

# install-tools.ps1
$InstallSageMath     = $true    # $false to skip (large ~1GB download)
$InstallPacketTracer = $false   # $true for Cisco Packet Tracer instructions
$InstallOffice       = $false   # $true to install Microsoft 365 (license required)
```

---

## What Gets Removed

- Xbox, Game Bar, Gaming Services
- Bing News, Weather, Finance, Sports
- Cortana, taskbar web search, Start Menu ads and suggestions
- Solitaire, Candy Crush, Mahjong, 3D apps
- Teams (personal), People, Phone Link, Mail & Calendar
- Groove Music, Movies & TV, Mixed Reality Portal
- Telemetry services (DiagTrack, dmwappushservice)
- Advertising ID, app tracking, Windows Spotlight

---

## What Gets Installed

| Tool | Purpose |
|------|---------|
| Firefox, Chrome | Browsers |
| VS Code | Code editor |
| Python 3.12 | Scripting and programming |
| Node.js LTS | JavaScript runtime |
| Java JDK 21 | Java development |
| Dev-C++ | C/C++ IDE |
| MSYS2 / MinGW | GCC compiler toolchain |
| XAMPP | PHP + Apache + MySQL |
| Git | Version control |
| SageMath | Mathematics software |
| Cisco Packet Tracer | Network simulation |
| Microsoft 365 | Office suite |
| 7-Zip, VLC, Notepad++ | Utilities |

---

## After Running

```powershell
# 1. Set up MSYS2 GCC compiler (open MSYS2 terminal after install)
pacman -Syu
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb mingw-w64-x86_64-make

# 2. Verify key tools are working
git --version
python --version
node --version
java -version
code --version
```

Then:
1. **Restart the machine**
2. **Run Windows Update**
3. **Activate Office** - sign in with your institution's Microsoft account
4. **Packet Tracer** - requires a free account at [netacad.com](https://www.netacad.com)
5. **SageMath** (if winget failed) - download from [sagemath.org](https://www.sagemath.org)

---

## Troubleshooting

**`winget: command not found`**
```powershell
# Option 1 - trigger Windows Update (winget comes via App Installer update)
# Option 2 - the script will auto-bootstrap winget if missing
# Option 3 - install manually from Microsoft Store (App Installer)
```

**App reinstalls after Windows Update**
```powershell
# Re-run the cleanup script - Windows re-provisions some apps after major updates
Set-ExecutionPolicy Bypass -Scope Process -Force
.\remove-bloatware.ps1
```

**Execution policy error**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

**`[!] Could not remove app` errors**
Safe to ignore - some apps are system-protected and won't affect performance.

**Failed winget installs**
```powershell
winget source update
.\install-tools.ps1
```

---

## Requirements

- Windows 10 20H2 or later
- PowerShell 5.1+ (built into Windows 10)
- Administrator rights
- Internet connection

---

## License

MIT - free to use, modify, and share.
