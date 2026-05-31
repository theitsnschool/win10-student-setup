#Requires -RunAsAdministrator

$RemoveOneDrive = $false
$RemoveSkype    = $true
$VerboseOutput  = $true

function Remove-UWPApp {
    param([string]$AppName)
    $removed = $false

    $provPkgs = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $AppName }
    foreach ($prov in $provPkgs) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop | Out-Null
            if ($VerboseOutput) { Write-Host "  [-] Deprovisioned: $AppName" -ForegroundColor Yellow }
            $removed = $true
        } catch {
            if ($VerboseOutput) { Write-Host "  [!] Deprovision failed: $AppName" -ForegroundColor DarkYellow }
        }
    }

    $pkgs = Get-AppxPackage -AllUsers -Name $AppName -ErrorAction SilentlyContinue
    foreach ($pkg in $pkgs) {
        try {
            Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
            if ($VerboseOutput) { Write-Host "  [-] Removed: $AppName" -ForegroundColor Yellow }
            $removed = $true
        } catch {
            $errMsg = $_.ToString()
            if ($errMsg -match "0x80070002" -or $errMsg -match "Removal failed") {
                if ($VerboseOutput) { Write-Host "  [~] Stale entry for $AppName - trying DISM..." -ForegroundColor DarkYellow }
                $dismResult = dism /Online /Get-ProvisionedAppxPackages 2>$null |
                    Select-String "PackageName" |
                    Where-Object { $_ -match ($AppName -replace "\.", "\.") }
                if ($dismResult) {
                    $dismPkgName = ($dismResult -split ": ")[-1].Trim()
                    dism /Online /Remove-ProvisionedAppxPackage /PackageName:$dismPkgName /Quiet 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        if ($VerboseOutput) { Write-Host "  [-] DISM removed: $AppName" -ForegroundColor Yellow }
                        $removed = $true
                    } else {
                        if ($VerboseOutput) { Write-Host "  [!] DISM also failed for $AppName (system-protected)" -ForegroundColor Red }
                    }
                } else {
                    if ($VerboseOutput) { Write-Host "  [~] Dead registry entry for $AppName - skipping" -ForegroundColor DarkGray }
                    $removed = $true
                }
            } else {
                if ($VerboseOutput) { Write-Host "  [!] Could not remove $AppName`: $errMsg" -ForegroundColor Red }
            }
        }
    }

    if (-not $removed) {
        if ($VerboseOutput) { Write-Host "  [=] Not present: $AppName" -ForegroundColor DarkGray }
    }
}

function Disable-Service {
    param([string]$ServiceName, [string]$Description)
    $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
        Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
        if ($VerboseOutput) { Write-Host "  [x] Disabled: $Description ($ServiceName)" -ForegroundColor Cyan }
    }
}

function Set-RegistryValue {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1 - Deep System Cleanup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "[CLEANUP 1/6] Flushing DNS cache..." -ForegroundColor Green
ipconfig /flushdns | Out-Null
Write-Host "  [+] DNS cache flushed" -ForegroundColor Green

Write-Host ""
Write-Host "[CLEANUP 2/6] Clearing temp files..." -ForegroundColor Green
$tempPaths = @(
    $env:TEMP,
    $env:TMP,
    "C:\Windows\Temp",
    "C:\Windows\Prefetch"
)
foreach ($path in $tempPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Cleared: $path" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "[CLEANUP 3/6] Clearing Windows Update cache..." -ForegroundColor Green
Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
$wuCachePath = "C:\Windows\SoftwareDistribution\Download"
if (Test-Path $wuCachePath) {
    Remove-Item -Path "$wuCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [+] Windows Update download cache cleared" -ForegroundColor Green
}
Start-Service -Name wuauserv -ErrorAction SilentlyContinue
Start-Service -Name bits -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[CLEANUP 4/6] Emptying Recycle Bin..." -ForegroundColor Green
$shell = New-Object -ComObject Shell.Application
$recycleBin = $shell.Namespace(0xA)
$recycleBin.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "  [+] Recycle Bin emptied" -ForegroundColor Green

Write-Host ""
Write-Host "[CLEANUP 5/6] Clearing Windows Event Logs..." -ForegroundColor Green
$logs = @("Application", "System", "Security", "Setup")
foreach ($log in $logs) {
    try {
        wevtutil cl $log 2>&1 | Out-Null
        Write-Host "  [+] Cleared log: $log" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Could not clear log: $log" -ForegroundColor DarkYellow
    }
}

Write-Host ""
Write-Host "[CLEANUP 6/6] Running Disk Cleanup (silent)..." -ForegroundColor Green
$cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
$sageSets = @(
    "Active Setup Temp Folders", "BranchCache", "Downloaded Program Files",
    "Internet Cache Files", "Memory Dump Files", "Old ChkDsk Files",
    "Previous Installations", "Recycle Bin", "Service Pack Cleanup",
    "Setup Log Files", "System error memory dump files", "System error minidump files",
    "Temporary Files", "Temporary Setup Files", "Temporary Sync Files",
    "Thumbnail Cache", "Update Cleanup", "Upgrade Discarded Files",
    "Windows Defender", "Windows Error Reporting Archive Files",
    "Windows Error Reporting Queue Files", "Windows Error Reporting System Archive Files",
    "Windows Error Reporting System Queue Files", "Windows ESD installation files",
    "Windows Upgrade Log Files"
)
foreach ($set in $sageSets) {
    $regPath = "$cleanupKey\$set"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "StateFlags0001" -Value 2 -Type DWord -Force
    }
}
Start-Process -FilePath cleanmgr.exe -ArgumentList "/sagerun:1" -Wait -NoNewWindow
Write-Host "  [+] Disk Cleanup complete" -ForegroundColor Green

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  PHASE 2 - Bloatware Removal" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "[1/9] Removing Xbox & Gaming apps..." -ForegroundColor Green
$xboxApps = @(
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay",
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.GamingServices",
    "Microsoft.XboxGameCallableUI"
)
foreach ($app in $xboxApps) { Remove-UWPApp $app }
Disable-Service "XblAuthManager"  "Xbox Live Auth Manager"
Disable-Service "XblGameSave"     "Xbox Live Game Save"
Disable-Service "XboxGipSvc"      "Xbox Accessory Management"
Disable-Service "XboxNetApiSvc"   "Xbox Live Networking"

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
Set-RegistryValue "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0
Write-Host "  [x] Game Bar (DVR) disabled" -ForegroundColor Cyan

Write-Host ""
Write-Host "[2/9] Removing consumer/entertainment apps..." -ForegroundColor Green
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

Write-Host ""
Write-Host "[3/9] Removing communication/social apps..." -ForegroundColor Green
$commApps = @(
    "Microsoft.YourPhone",
    "Microsoft.People",
    "Microsoft.Messaging",
    "Microsoft.windowscommunicationsapps",
    "MicrosoftTeams"
)
foreach ($app in $commApps) { Remove-UWPApp $app }
if ($RemoveSkype) { Remove-UWPApp "Microsoft.SkypeApp" }

Write-Host ""
Write-Host "[4/9] Disabling Cortana & taskbar web search..." -ForegroundColor Green
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "BingSearchEnabled" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
Write-Host "  [x] Cortana disabled via policy" -ForegroundColor Cyan
Remove-UWPApp "Microsoft.549981C3F5F10"

Write-Host ""
Write-Host "[5/9] Removing unnecessary utilities..." -ForegroundColor Green
$utilApps = @(
    "Microsoft.Windows.Photos",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Office.OneNote",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.Advertising.Xaml",
    "Microsoft.Services.Store.Engagement",
    "Microsoft.WindowsAlarms",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftEdge.Stable",
    "Microsoft.Todos",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.ScreenSketch"
)
foreach ($app in $utilApps) { Remove-UWPApp $app }

Write-Host ""
Write-Host "[6/9] Removing remaining bloat from AppxPackage list..." -ForegroundColor Green
$extraApps = @(
    "Microsoft.Windows.ContentDeliveryManager",
    "Microsoft.Windows.PeopleExperienceHost",
    "Microsoft.Windows.Search",
    "Microsoft.Windows.StartMenuExperienceHost",
    "Microsoft.StorePurchaseApp",
    "Microsoft.WindowsStore",
    "Microsoft.VP9VideoExtensions",
    "Microsoft.WebMediaExtensions",
    "Microsoft.WebpImageExtension",
    "Microsoft.HEIFImageExtension",
    "Microsoft.Windows.Photos",
    "Microsoft.ECApp",
    "Microsoft.BioEnrollment",
    "Microsoft.CredDialogHost",
    "Microsoft.Win32WebViewHost",
    "Microsoft.Windows.AssignedAccessLockApp",
    "Microsoft.Windows.CapturePicker",
    "Microsoft.Windows.CloudExperienceHost",
    "Microsoft.Windows.NarratorQuickStart",
    "Microsoft.Windows.OOBENetworkCaptivePortal",
    "Microsoft.Windows.OOBENetworkConnectionFlow",
    "Microsoft.Windows.ParentalControls",
    "Microsoft.Windows.PinningConfirmationDialog",
    "Microsoft.Windows.SecHealthUI",
    "Microsoft.Windows.SecureAssessmentBrowser",
    "Microsoft.Windows.XGpuEjectDialog",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsFeedback",
    "MicrosoftWindows.Client.CBS",
    "MicrosoftWindows.UndockedDevKit",
    "NcsiUwpApp",
    "Windows.CBSPreview",
    "windows.immersivecontrolpanel"
)
foreach ($app in $extraApps) { Remove-UWPApp $app }

if ($RemoveOneDrive) {
    Write-Host ""
    Write-Host "[7/9] Removing OneDrive..." -ForegroundColor Green
    Stop-Process -Name "OneDrive" -Force -ErrorAction SilentlyContinue
    $od32 = "$env:SystemRoot\System32\OneDriveSetup.exe"
    $od64 = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
    if (Test-Path $od64)     { & $od64 /uninstall }
    elseif (Test-Path $od32) { & $od32 /uninstall }
    Remove-Item -Path "$env:USERPROFILE\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:ProgramData\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
    $regPath = "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
    if (Test-Path $regPath) {
        Set-ItemProperty -Path $regPath -Name "System.IsPinnedToNameSpaceTree" -Value 0 -Force
    }
    Write-Host "  [x] OneDrive removed" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[7/9] Skipping OneDrive removal (set RemoveOneDrive=true to enable)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[8/9] Cleaning Start Menu & UI..." -ForegroundColor Green
$startPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
$cdmProps = @{
    "ContentDeliveryAllowed"            = 0
    "OemPreInstalledAppsEnabled"        = 0
    "PreInstalledAppsEnabled"           = 0
    "PreInstalledAppsEverEnabled"       = 0
    "SilentInstalledAppsEnabled"        = 0
    "SubscribedContent-338387Enabled"   = 0
    "SubscribedContent-338388Enabled"   = 0
    "SubscribedContent-338389Enabled"   = 0
    "SubscribedContent-353698Enabled"   = 0
    "SystemPaneSuggestionsEnabled"      = 0
    "RotatingLockScreenEnabled"         = 0
    "RotatingLockScreenOverlayEnabled"  = 0
    "SoftLandingEnabled"                = 0
    "SubscribedContentEnabled"          = 0
}
foreach ($key in $cdmProps.Keys) {
    Set-RegistryValue $startPath $key $cdmProps[$key]
}
Write-Host "  [x] Start Menu ads and suggestions disabled" -ForegroundColor Cyan

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0
Write-Host "  [x] Task View button hidden" -ForegroundColor Cyan

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 0
Write-Host "  [x] Taskbar search box hidden" -ForegroundColor Cyan

Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
Write-Host "  [x] Telemetry disabled via policy" -ForegroundColor Cyan

Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "AITEnable" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat" "DisableInventory" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows" "CEIPEnable" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\TabletPC" "PreventHandwritingDataSharing" 1
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\TextInput" "AllowLinguisticDataCollection" 0
Write-Host "  [x] Additional telemetry and data collection disabled" -ForegroundColor Cyan

Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Write-Host "  [x] Advertising ID disabled" -ForegroundColor Cyan

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackDocs" 0
Write-Host "  [x] Recent files and app tracking disabled" -ForegroundColor Cyan

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0
Write-Host "  [x] Chat (Teams) icon removed from taskbar" -ForegroundColor Cyan

Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0
Write-Host "  [x] Copilot button hidden from taskbar" -ForegroundColor Cyan

Disable-Service "DiagTrack"        "Connected User Experiences and Telemetry"
Disable-Service "dmwappushservice" "WAP Push Message Routing"
Disable-Service "SysMain"          "SysMain (Superfetch)"
Disable-Service "WSearch"          "Windows Search Indexer"
Disable-Service "RetailDemo"       "Retail Demo Service"
Disable-Service "MapsBroker"       "Downloaded Maps Manager"
Disable-Service "lfsvc"            "Geolocation Service"
Disable-Service "SharedAccess"     "Internet Connection Sharing"
Disable-Service "TrkWks"           "Distributed Link Tracking Client"
Disable-Service "WerSvc"           "Windows Error Reporting"

Write-Host ""
Write-Host "[9/9] Blocking bloatware from returning after Windows Update..." -ForegroundColor Green
$provApps = @(
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GamingServices",
    "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftSolitaireCollection", "Microsoft.People",
    "Microsoft.PowerAutomateDesktop", "Microsoft.Todos",
    "Microsoft.WindowsCommunicationsApps", "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps", "Microsoft.Xbox.TCUI", "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider", "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "MicrosoftTeams"
)
foreach ($app in $provApps) {
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -eq $app }
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction SilentlyContinue | Out-Null
        Write-Host "  [-] Deprovisioned: $app" -ForegroundColor Yellow
    }
}
Write-Host "  [+] Provisioned app list cleaned" -ForegroundColor Green

Write-Host ""
Write-Host "  [DONE] Bloatware removal and deep cleanup complete." -ForegroundColor Green
Write-Host "  Restart the machine for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Note: Any [!] lines above are system-protected and can be safely ignored." -ForegroundColor DarkGray