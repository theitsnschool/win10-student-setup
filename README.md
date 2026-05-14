# win10-student-setup

> Automated Windows 10 cleanup and setup scripts for student lab machines.
> Designed for: **Web browsing, Office, Python, Java, C/C++, PHP, SAGE, Packet Tracer**

---

## What this does

| Script | Purpose |
|--------|---------|
| `remove-bloatware.ps1` | Removes Xbox, games, Cortana, consumer apps, cleans Start Menu |
| `install-tools.ps1` | Installs all needed dev and productivity tools via winget |
| `run-all.ps1` | Master launcher -- runs both scripts in the correct order |

---

## Quick start (fresh Windows 10 install)

Open **PowerShell as Administrator** and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
irm https://raw.githubusercontent.com/bkaztaou/win10-student-setup/main/run-all.ps1 | iex
```

> Replace `bkaztaou` with your GitHub username.

That's it. The script will clean the system and install all tools automatically.

---

## What gets removed

### Xbox & Gaming
- Xbox app, Xbox Game Bar, Xbox Identity Provider, Gaming Services
- Xbox background services (XblAuthManager, XblGameSave, XboxGipSvc, XboxNetApiSvc)

### Consumer & Entertainment
- Solitaire, Mahjong, Jigsaw Puzzle
- Candy Crush, Bubble Witch (carrier-installed)
- Groove Music, Movies & TV, Mixed Reality Portal
- Bing News, Weather, Finance, Sports
- 3D Viewer, Paint 3D, Print 3D

### Communication & Social
- Phone Link (Your Phone)
- Microsoft Teams (personal preinstalled version)
- People, Messaging, Mail & Calendar

### Cortana & Telemetry
- Cortana UWP app + web search in taskbar disabled via Group Policy
- Start Menu ads, suggested apps, Windows Spotlight ads

---

## What gets installed

### Development
| Tool | Purpose |
|------|---------|
| Python 3 | Scripting, data, general programming |
| Java JDK 21 (Eclipse Temurin) | Java development |
| Git | Version control |
| Visual Studio Code | Lightweight code editor |
| Dev-C++ | C/C++ IDE (used in many CS courses) |
| XAMPP | PHP + Apache + MySQL local server |
| Node.js LTS | JavaScript runtime (used by some tools) |

### Networking & Math
| Tool | Purpose |
|------|---------|
| Cisco Packet Tracer | Network simulation (requires Cisco NetAcad account) |
| SageMath | Open-source mathematics software |

### Productivity & Browsers
| Tool | Purpose |
|------|---------|
| Mozilla Firefox | Primary web browser |
| Google Chrome | Secondary browser |
| 7-Zip | Archive manager |
| VLC | Media player |
| Notepad++ | Text/code viewer |

> **Note:** Microsoft Office and Cisco Packet Tracer require a license or account.
> The script will download the installers but you will need to sign in to activate them.

---

## How to run individual scripts

If you only want to do one part:

```powershell
# Remove bloatware only
Set-ExecutionPolicy Bypass -Scope Process -Force
.\remove-bloatware.ps1

# Install tools only
Set-ExecutionPolicy Bypass -Scope Process -Force
.\install-tools.ps1
```

---

## Configuration options

At the top of each script there are flags you can toggle:

**`remove-bloatware.ps1`**
```powershell
$RemoveOneDrive = $false   # Set $true to uninstall OneDrive
$RemoveSkype    = $true    # Set $false to keep Skype
```

**`install-tools.ps1`**
```powershell
$InstallSageMath      = $true   # Set $false to skip SageMath (large download)
$InstallPacketTracer  = $false  # Set $true to download Packet Tracer installer
$InstallOffice        = $false  # Set $true to launch Office installer (requires license)
```

---

## Requirements

- Windows 10 (20H2 or later)
- PowerShell 5.1+ (included in Windows 10)
- Administrator rights
- Internet connection (for winget downloads)
- winget (pre-installed on Windows 10 1809+ via App Installer)

---

## After running

1. **Restart the machine** -- some changes require a reboot
2. **Run Windows Update** -- install all pending security patches
3. **Activate Office** -- sign in with your institution's Microsoft account
4. **Install Packet Tracer** -- requires a free Cisco NetAcad account at [netacad.com](https://www.netacad.com)
5. **Install SAGE** -- if not available via winget, download from [sagemath.org](https://www.sagemath.org)

---

## Troubleshooting

**`[!] Could not remove app` errors**
Some apps are system-protected on certain Windows editions. These are safe to ignore -- they won't affect performance.

**`winget : command not found`**
Run Windows Update first -- winget is delivered via the App Installer update. Or install it manually from the [Microsoft Store](https://apps.microsoft.com/detail/9nblggh4nns1).

**App reinstalls after update**
Run `remove-bloatware.ps1` again after the first major Windows Update to catch anything that was re-provisioned.

**Execution policy error**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
```
Run this first in the same PowerShell window.

---

## Repo structure

```
win10-student-setup/
├── README.md
├── run-all.ps1
├── remove-bloatware.ps1
└── install-tools.ps1
```

---

## License

MIT -- free to use, modify, and share.