#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Removes Windows 10 bloatware for a student dev/office machine.
.DESCRIPTION
    Removes preinstalled UWP apps, disables Xbox services, Cortana,
    OneDrive (optional), and cleans up the Start Menu.
    Safe for: Office, Web browsing, Python, Java, C/C++, PHP, Packet Tracer, SAGE.
.NOTES
    Run as Administrator in PowerShell.
    Tested on Windows 10 20H2 and later.
    Handles error 0x80070002 (stale registry entries with missing files).
#>

# ---------------------------------------------
# CONFIGURATION
# ---------------------------------------------
$RemoveOneDrive  = $false   # Set $true if you don't use M365/OneDrive
$RemoveSkype     = $true    # Preinstalled UWP Skype (not desktop app)
$VerboseOutput   = $true    # Print each action

# ---------------------------------------------
# HELPER: Remove a UWP app robustly
# Handles 0x80070002 (stale entries) via DISM fallback
# ---------------------------------------------
function Remove-UWPApp {
    param([string]$AppName)
    $removed = $false

    # Step 1: Deprovision first (stops reinstall for new user accounts)
    $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like $AppName }
    foreach ($prov in $provPkgs) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            if ($VerboseOutput) { Write-Host "  [-] Deprovisioned: $AppName" -ForegroundColor Yellow }
            $removed = $true
        } catch {
            if ($VerboseOutput) { Write-Host "  [!] Deprovision failed for $AppName" -ForegroundColor DarkYellow }
        }
    }

    # Step 2: Remove installed instances for all users
    $pkgs = Get-AppxPackage -AllUsers -Name $AppName -ErrorAction SilentlyContinue
    foreach ($pkg in $pkgs) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
            if ($VerboseOutput) { Write-Host "  [-] Removed: $AppName" -ForegroundColor Yellow }
            $removed = $true
        } catch {
            $errMsg = $_.ToString()
            if ($errMsg -match "0x80070002" -or $errMsg -match "Removal failed") {
                if ($VerboseOutput) { Write-Host "  [~] Stale entry for $AppName - trying DISM cleanup..." -ForegroundColor DarkYellow }
                $dismResult = dism /Online /Get-ProvisionedAppxPackages 2>$null |
                              Select-String "PackageName" |
                              Where-Object { $_ -match ($AppName -replace "\.", "\.") }
                if ($dismResult) {
                    $dismPkgName = ($dismResult -split ": ")[-1].Trim()
                    dism /Online /Remove-ProvisionedAppxPackage /PackageName:$dismPkgName /Quiet 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        if ($VerboseOutput) { Write-Host "  [-] DISM removed stale entry: $AppName" -ForegroundColor Yellow }
                        $removed = $true
                    } else {
                        if ($VerboseOutput) { Write-Host "  [!] DISM also failed for $AppName (system-protected, safe to ignore)" -ForegroundColor Red }
                    }
                } else {
                    if ($VerboseOutput) { Write-Host "  [~] Dead registry entry for $AppName - skipping (harmless)" -ForegroundColor DarkGray }
                    $removed = $true
                }
            } else {
                if ($VerboseOutput) { Write-Host "  [!] Could not remove $AppName : $errMsg" -ForegroundColor Red }
            }
        }
    }

    if (-not $removed) {
        if ($VerboseOutput) { Write-Host "  [=] Already removed or not present: $AppName" -ForegroundColor DarkGray }
    }
}

function Disable-Service {
    param([string]$ServiceName, [string]$Description)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
        if ($VerboseOutput) { Write-Host "  [x] Disabled: $Description ($ServiceName)" -ForegroundColor Cyan }
    }
}

# ---------------------------------------------
# 1. XBOX & GAMING
# ---------------------------------------------
Write-Host ""
Write-Host "[1/7] Removing Xbox & Gaming apps..." -ForegroundColor Green
$xboxApps = @(
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.GamingServices"
)
foreach ($app in $xboxApps) { Remove-UWPApp $app }

Disable-Service "XblAuthManager" "Xbox Live Auth Manager"
Disable-Service "XblGameSave"    "Xbox Live Game Save"
Disable-Service "XboxGipSvc"     "Xbox Accessory Management"
Disable-Service "XboxNetApiSvc"  "Xbox Live Networking"

$gameDVRPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gameDVRPath)) { New-Item -Path $gameDVRPath -Force | Out-Null }
Set-ItemProperty -Path $gameDVRPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
Write-Host "  [x] Disabled Game Bar (DVR)" -ForegroundColor Cyan

# ---------------------------------------------
# 2. CONSUMER / ENTERTAINMENT APPS
# ---------------------------------------------
Write-Host ""
Write-Host "[2/7] Removing consumer/entertainment apps..." -ForegroundColor Green
$consumerApps = @(
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftMahjong",
    "Microsoft.MicrosoftJigsawPuzzle",
    "king.com.CandyCrushSodaSaga",
    "king.com.CandyCrushFriends",
    "king.com.BubbleWitch3Saga",
    "Microsoft.BingNews",
    "Microsoft.BingWeather",
    "Microsoft.BingFinance",
    "Microsoft.BingSports",
    "Microsoft.WindowsMaps",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.MixedReality.Portal",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.Print3D",
    "Microsoft.3DBuilder",
    "Microsoft.MSPaint"
)
foreach ($app in $consumerApps) { Remove-UWPApp $app }

# ---------------------------------------------
# 3. COMMUNICATION & SOCIAL APPS
# ---------------------------------------------
Write-Host ""
Write-Host "[3/7] Removing unwanted communication apps..." -ForegroundColor Green
$commApps = @(
    "Microsoft.YourPhone",
    "Microsoft.People",
    "Microsoft.Messaging",
    "Microsoft.windowscommunicationsapps",
    "MicrosoftTeams"
)
foreach ($app in $commApps) { Remove-UWPApp $app }
if ($RemoveSkype) { Remove-UWPApp "Microsoft.SkypeApp" }

# ---------------------------------------------
# 4. CORTANA & WEB SEARCH IN TASKBAR
# ---------------------------------------------
Write-Host ""
Write-Host "[4/7] Disabling Cortana & taskbar web search..." -ForegroundColor Green
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana"      -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "DisableWebSearch"  -Value 1 -Type DWord -Force
Write-Host "  [x] Cortana disabled via policy" -ForegroundColor Cyan
Remove-UWPApp "Microsoft.549981C3F5F10"

# ---------------------------------------------
# 5. MISC WINDOWS UTILITIES
# ---------------------------------------------
Write-Host ""
Write-Host "[5/7] Removing unnecessary utilities..." -ForegroundColor Green
$utilApps = @(
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Office.OneNote",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Advertising.Xaml",
    "Microsoft.Services.Store.Engagement",
    "Microsoft.WindowsAlarms"
)
foreach ($app in $utilApps) { Remove-UWPApp $app }

# ---------------------------------------------
# 6. ONEDRIVE (OPTIONAL)
# ---------------------------------------------
if ($RemoveOneDrive) {
    Write-Host ""
    Write-Host "[6/7] Removing OneDrive..." -ForegroundColor Green
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    $od32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $od64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $od64)     { & $od64 /uninstall }
    elseif (Test-Path $od32) { & $od32 /uninstall }
    Remove-Item -Path "$env:USERPROFILE\OneDrive"            -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft OneDrive"  -Recurse -Force -ErrorAction SilentlyContinue
    $regPath = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Force
    }
    Write-Host "  [x] OneDrive removed" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[6/7] Skipping OneDrive (set RemoveOneDrive to true at top of script to enable)" -ForegroundColor DarkGray
}

# ---------------------------------------------
# 7. START MENU & UI CLEANUP
# ---------------------------------------------
Write-Host ""
Write-Host "[7/7] Cleaning Start Menu & UI..." -ForegroundColor Green
$startPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $startPath)) { New-Item -Path $startPath -Force | Out-Null }
$cdmProps = @{
    "ContentDeliveryAllowed"          = 0
    "OemPreInstalledAppsEnabled"      = 0
    "PreInstalledAppsEnabled"         = 0
    "PreInstalledAppsEverEnabled"     = 0
    "SilentInstalledAppsEnabled"      = 0
    "SubscribedContent-338387Enabled" = 0
    "SubscribedContent-338388Enabled" = 0
    "SubscribedContent-338389Enabled" = 0
    "SubscribedContent-353698Enabled" = 0
    "SystemPaneSuggestionsEnabled"    = 0
}
foreach ($key in $cdmProps.Keys) {
    Set-ItemProperty -Path $startPath -Name $key -Value $cdmProps[$key] -Type DWord -Force
}
Write-Host "  [x] Disabled Start Menu ads and suggestions" -ForegroundColor Cyan

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
Write-Host "  [x] Hidden Task View button" -ForegroundColor Cyan

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force
Write-Host "  [x] Hidden taskbar search box (Win key still works)" -ForegroundColor Cyan

# ---------------------------------------------
# DONE
# ---------------------------------------------
Write-Host ""
Write-Host "  [DONE] Bloatware removal complete." -ForegroundColor Green
Write-Host "  Restart the machine for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Note: Any [!] lines above are system-protected apps and can be safely ignored." -ForegroundColor DarkGray