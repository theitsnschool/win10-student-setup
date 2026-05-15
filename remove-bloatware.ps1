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
    "Active Setup Temp Folders",
    "BranchCache",
    "Downloaded Program Files",
    "Internet Cache Files",
    "Memory Dump Files",
    "Old ChkDsk Files",
    "Previous Installations",
    "Recycle Bin",
    "Service Pack Cleanup",
    "Setup Log Files",
    "System error memory dump files",
    "System error minidump files",
    "Temporary Files",
    "Temporary Setup Files",
    "Temporary Sync Files",
    "Thumbnail Cache",
    "Update Cleanup",
    "Upgrade Discarded Files",
    "Windows Defender",
    "Windows Error Reporting Archive Files",
    "Windows Error Reporting Queue Files",
    "Windows Error Reporting System Archive Files",
    "Windows Error Reporting System Queue Files",
    "Windows ESD installation files",
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
Disable-Service "XblAuthManager"  "Xbox Live Auth Manager"
Disable-Service "XblGameSave"     "Xbox Live Game Save"
Disable-Service "XboxGipSvc"      "Xbox Accessory Management"
Disable-Service "XboxNetApiSvc"   "Xbox Live Networking"

$gameDVRPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
if (-not (Test-Path $gameDVRPath)) { New-Item -Path $gameDVRPath -Force | Out-Null }
Set-ItemProperty -Path $gameDVRPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force
Write-Host "  [x] Game Bar (DVR) disabled" -ForegroundColor Cyan

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

Write-Host ""
Write-Host "[3/7] Removing communication/social apps..." -ForegroundColor Green
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
Write-Host "[4/7] Disabling Cortana & taskbar web search..." -ForegroundColor Green
$cortanaPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $cortanaPath)) { New-Item -Path $cortanaPath -Force | Out-Null }
Set-ItemProperty -Path $cortanaPath -Name "AllowCortana"    -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "BingSearchEnabled" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $cortanaPath -Name "DisableWebSearch" -Value 1 -Type DWord -Force
Write-Host "  [x] Cortana disabled via policy" -ForegroundColor Cyan
Remove-UWPApp "Microsoft.549981C3F5F10"

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
    "Microsoft.WindowsAlarms",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.MicrosoftEdge.Stable",
    "Microsoft.Todos",
    "Microsoft.PowerAutomateDesktop",
    "Microsoft.ScreenSketch"
)
foreach ($app in $utilApps) { Remove-UWPApp $app }

if ($RemoveOneDrive) {
    Write-Host ""
    Write-Host "[6/7] Removing OneDrive..." -ForegroundColor Green
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
    Write-Host "[6/7] Skipping OneDrive removal (set RemoveOneDrive=true to enable)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[7/7] Cleaning Start Menu & UI..." -ForegroundColor Green
$startPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $startPath)) { New-Item -Path $startPath -Force | Out-Null }
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
}
foreach ($key in $cdmProps.Keys) {
    Set-ItemProperty -Path $startPath -Name $key -Value $cdmProps[$key] -Type DWord -Force
}
Write-Host "  [x] Start Menu ads and suggestions disabled" -ForegroundColor Cyan

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "ShowTaskViewButton" -Value 0 -Type DWord -Force
Write-Host "  [x] Task View button hidden" -ForegroundColor Cyan

Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" `
    -Name "SearchboxTaskbarMode" -Value 0 -Type DWord -Force
Write-Host "  [x] Taskbar search box hidden" -ForegroundColor Cyan

$telemetryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $telemetryPath)) { New-Item -Path $telemetryPath -Force | Out-Null }
Set-ItemProperty -Path $telemetryPath -Name "AllowTelemetry" -Value 0 -Type DWord -Force
Write-Host "  [x] Telemetry disabled via policy" -ForegroundColor Cyan

Disable-Service "DiagTrack"        "Connected User Experiences and Telemetry"
Disable-Service "dmwappushservice" "WAP Push Message Routing"
Disable-Service "SysMain"          "SysMain (Superfetch)"

Write-Host ""
Write-Host "  [DONE] Bloatware removal and deep cleanup complete." -ForegroundColor Green
Write-Host "  Restart the machine for all changes to take effect." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Note: Any [!] lines above are system-protected and can be safely ignored." -ForegroundColor DarkGray