# win10-student-setup

Automated Windows 10 cleanup and full dev environment setup for student lab machines.

Removes all bloatware, installs every tool you need, and activates Windows and Office - all in one run.

---

## What This Does

| Script | Purpose |
|--------|---------|
| `remove-bloatware.ps1` | Removes Xbox, games, Cortana, telemetry, cleans Start Menu |
| `install-tools.ps1` | Installs all dev and productivity tools via winget |
| `install-office.ps1` | Installs Microsoft 365 and activates Windows + Office |
| `run-all.ps1` | Runs all three scripts in the correct order |

---

## Full Setup Guide (Do This Once)

Follow these steps exactly, in order.

### Step 1 - Open PowerShell as Administrator

Press `Win + S`, type `PowerShell`, right-click **Windows PowerShell** and select **Run as administrator**.

You should see a blue terminal window with a title like `Administrator: Windows PowerShell`.

### Step 2 - Run the Master Script

Paste this into the PowerShell window and press Enter:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/run-all.ps1 | iex
```

The script will now run automatically through 3 phases:

- **Phase 1** - System cleanup and bloatware removal (~2-5 min)
- **Phase 2** - Tool installation via winget (~15-30 min depending on internet speed)
- **Phase 3** - Microsoft Office installation + Windows and Office activation (interactive)

> During Phase 3, an activation menu will appear. Select **[1] HWID** to activate Windows, then run it again and select **[2] Ohook** to activate Office.

### Step 3 - Set Up MSYS2 GCC Compiler

After the script finishes, open the **MSYS2** app from the Start Menu and run:

```bash
pacman -Syu
```

Close and reopen MSYS2, then run:

```bash
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-gdb mingw-w64-x86_64-make
```

This installs the GCC C/C++ compiler used in Dev-C++ and VS Code.

### Step 4 - Restart the Machine

Restart Windows to apply all PATH, registry, and service changes.

### Step 5 - Run Windows Update

After restart, go to **Settings > Windows Update** and install all available updates. This ensures your security patches are current and no bloatware gets re-provisioned.

### Step 6 - Verify Everything Works

Open a new PowerShell window and run:

```powershell
git --version
python --version
node --version
java -version
code --version
gcc --version
```

Every command should return a version number. If any fail, see the Troubleshooting section below.

### Step 7 - Sign In to Office

Open any Office app (Word, Excel, etc.) and sign in with your institution's Microsoft account to link your license.

### Step 8 - Install Cisco Packet Tracer (if needed)

Packet Tracer requires a free Cisco NetAcad account:

1. Create an account at [netacad.com](https://www.netacad.com)
2. Enroll in any free course (e.g. "Introduction to Packet Tracer")
3. Download Packet Tracer from your course resources page

---

## What Gets Removed

- Xbox, Game Bar, Gaming Services and all Xbox background services
- Bing News, Weather, Finance, Sports
- Cortana, taskbar web search, Start Menu ads and suggestions
- Solitaire, Candy Crush, Mahjong, 3D Viewer, Paint 3D
- Teams (personal preinstall), People, Phone Link, Mail and Calendar
- Groove Music, Movies and TV, Mixed Reality Portal
- Telemetry and data collection services (DiagTrack, dmwappushservice)
- Advertising ID, app usage tracking, Windows Spotlight
- Windows Error Reporting, Superfetch, Geolocation service

---

## What Gets Installed

| Tool | Purpose |
|------|---------|
| Firefox, Chrome | Browsers |
| VS Code | Code editor with Python, Java, C++, PHP extensions |
| Python 3.12 | Scripting and programming |
| Node.js LTS | JavaScript runtime |
| Java JDK 21 | Java development (JAVA_HOME set automatically) |
| Dev-C++ | C/C++ IDE |
| MSYS2 / MinGW | GCC compiler toolchain (manual step required, see above) |
| XAMPP | PHP + Apache + MySQL local server |
| Git | Version control (configured with sane defaults) |
| Microsoft 365 | Office suite (activated via Ohook) |
| Cisco Packet Tracer | Network simulation (manual step required, see above) |
| 7-Zip, VLC, Notepad++ | Utilities |
| Windows Terminal | Modern terminal |
| PowerShell 7 | Modern PowerShell |

**VS Code extensions installed automatically:**
- Python, Pylint, Debugpy
- Java Extension Pack
- C/C++ and C/C++ Extension Pack
- PHP Intelephense
- Live Server, Prettier, GitLens
- Code Runner, PowerShell, Spell Checker

**Python packages installed automatically:**
- requests, numpy, matplotlib, pandas, virtualenv

---

## Run Individual Scripts

If you only need to run one part, download the scripts first:

```powershell
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/remove-bloatware.ps1" -OutFile "remove-bloatware.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/install-tools.ps1" -OutFile "install-tools.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/install-office.ps1" -OutFile "install-office.ps1"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/run-all.ps1" -OutFile "run-all.ps1"
```

Then run whichever you need:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force

.\remove-bloatware.ps1   # Cleanup only
.\install-tools.ps1      # Install tools only
.\install-office.ps1     # Install Office + activate Windows and Office
```

---

## Configuration

Edit the flags at the top of each script before running if you want to customize behavior:

```powershell
# remove-bloatware.ps1
$RemoveOneDrive = $false   # $true to uninstall OneDrive completely
$RemoveSkype    = $true    # $false to keep Skype

# install-tools.ps1
$InstallPacketTracer = $false   # $true to show Packet Tracer download instructions
```

---

## Troubleshooting

**Execution policy error**

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```

Run this in the same PowerShell window before running any script.

---

**`winget: command not found`**

The script will auto-bootstrap winget if it is missing. If that also fails:

1. Open **Microsoft Store**
2. Search for **App Installer**
3. Install or update it
4. Close and reopen PowerShell, then retry

---

**`[!] Could not remove app` errors**

Safe to ignore. Apps marked as system-protected (like `SecHealthUI`, `ContentDeliveryManager`) are part of Windows core and cannot be removed via AppX. They do not affect performance or add ads.

---

**An app failed to install**

```powershell
winget source update
.\install-tools.ps1
```

Refreshing winget sources and re-running the script is usually enough. Already-installed apps will be skipped automatically.

---

**Bloatware came back after Windows Update**

Windows sometimes re-provisions removed apps after a major update. Re-run the cleanup:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\remove-bloatware.ps1
```

---

**GCC not found after MSYS2 install**

Make sure you opened the **MSYS2 MINGW64** terminal (not MSYS2 MSYS), and ran both `pacman` commands in Step 3. Also add `C:\msys64\mingw64\bin` to your system PATH if VS Code cannot find `gcc`.

---

**Office activation failed**

Re-run the activation script manually:

```powershell
irm https://get.activated.win | iex
```

Select **[2] Ohook** from the menu for Office.

---

## Requirements

- Windows 10 20H2 or later
- PowerShell 5.1+ (built into Windows 10)
- Administrator rights
- Internet connection

---

## Repo Structure

```
win10-student-setup/
├── README.md
├── run-all.ps1
├── remove-bloatware.ps1
├── install-tools.ps1
└── install-office.ps1
```

---

## License

MIT - free to use, modify, and share.