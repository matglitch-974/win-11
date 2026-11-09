#Requires -Version 5.1
<#
.SYNOPSIS
    win-11 : convertit un Windows 11 classique en Windows 11 optimise.

.DESCRIPTION
    Moteur unique, utilise tel quel :
      - sur un Windows deja installe (menu interactif ou parametres) ;
      - dans l'ISO generee par build-iso.ps1 (lance au premier logon).
    Chaque valeur modifiee est journalisee avant changement :
    -Restore remet le systeme dans son etat d'origine.

.PARAMETER Profil
    Systeme     : performances pures (alimentation, CPU, GPU, latence, services, Defender allege).
    Complet     : Systeme + debloat + confidentialite + confort (Snap, fin de tache, volume par app).
    CompletOLED : Complet + theme noir pur pour ecrans OLED.

.PARAMETER Extreme
    Ajoute : VBS/HVCI off, mitigations Spectre/Meltdown off, hyperviseur off, Defender desactive.
    Gain reel en jeu, securite nettement reduite. WSL2 / Hyper-V / Docker ne fonctionnent plus.

.PARAMETER Navigateurs
    Desinstalle Edge et installe Firefox, Brave, Tor Browser.

.PARAMETER Groupes
    Personnalise : liste separee par des virgules parmi
    Power, Gpu, Storage, Services, DefenderLight, UpdatePolicy, Debloat, Privacy, Comfort, Oled, Browsers, Extreme.

.PARAMETER Restore
    Restaure depuis le dernier journal (ou -Journal <chemin>).

.EXAMPLE
    .\win11.ps1                         # menu
    .\win11.ps1 -Profil Complet
    .\win11.ps1 -Profil Systeme -Extreme -Silencieux
    .\win11.ps1 -Groupes Power,Gpu,Comfort
    .\win11.ps1 -Restore
#>
[CmdletBinding()]
param(
    [ValidateSet('Systeme', 'Complet', 'CompletOLED')]
    [string]$Profil,
    [switch]$Extreme,
    [switch]$Navigateurs,
    [switch]$SansMisesAJour,
    [switch]$Silencieux,
    [switch]$Restore,
    [string]$Journal,
    [string]$Groupes
)

Set-StrictMode -Off
$ErrorActionPreference = 'Continue'
$Script:Version   = '2.0.0'
$Script:DataDir   = "$env:ProgramData\win-11"
$Script:Entries   = New-Object System.Collections.Generic.List[object]
$Script:Seen      = @{}
$Script:Warnings  = New-Object System.Collections.Generic.List[string]

# ── Elevation ────────────────────────────────────────────────────────────────
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if (-not $PSCommandPath) {
        Write-Host 'Lancez PowerShell en administrateur.' -ForegroundColor Red
        exit 1
    }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($k in $PSBoundParameters.Keys) {
        $v = $PSBoundParameters[$k]
        if ($v -is [switch]) { if ($v) { $argList += "-$k" } } else { $argList += "-$k"; $argList += "`"$v`"" }
    }
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

# ── Journal (sauvegarde avant modification) ──────────────────────────────────
function Add-Entry($entry) { $Script:Entries.Add([pscustomobject]$entry) }

function Save-Journal {
    if ($Script:Entries.Count -eq 0) { return }
    if (-not (Test-Path $Script:DataDir)) { New-Item $Script:DataDir -ItemType Directory -Force | Out-Null }
    $path = Join-Path $Script:DataDir ("journal-{0}.json" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $Script:Entries | ConvertTo-Json -Depth 5 | Out-File $path -Encoding UTF8
    Write-Host "  Journal de restauration : $path" -ForegroundColor DarkGray
}

function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    $key = "$Path|$Name"
    if (-not $Script:Seen.ContainsKey($key)) {
        $Script:Seen[$key] = $true
        $old = $null; $oldType = $null; $existed = $false
        try {
            $item = Get-Item -Path $Path -ErrorAction Stop
            if ($item.GetValueNames() -contains $Name) {
                $existed = $true
                $old     = $item.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
                $oldType = $item.GetValueKind($Name).ToString()
                if ($old -is [byte[]]) { $old = [Convert]::ToBase64String($old); $oldType = 'Binary' }
            }
        } catch {}
        Add-Entry @{ Kind = 'Reg'; Path = $Path; Name = $Name; Existed = $existed; Value = $old; Type = $oldType }
    }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
    } catch { $Script:Warnings.Add("Registre refuse : $Path\$Name") }
}

function Set-Svc([string]$Name, [ValidateSet('Disabled','Manual','Automatic')][string]$Start = 'Disabled') {
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { return }
    $cur = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" -Name Start -ErrorAction SilentlyContinue).Start
    Add-Entry @{ Kind = 'Svc'; Name = $Name; Start = $cur }
    $num = @{ Automatic = 2; Manual = 3; Disabled = 4 }[$Start]
    try { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$Name" -Name Start -Value $num -ErrorAction Stop }
    catch { $Script:Warnings.Add("Service protege : $Name") }
    if ($Start -eq 'Disabled') { Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue }
}

function Disable-Task([string]$TPath, [string]$TName) {
    $t = Get-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue
    if (-not $t -or $t.State -eq 'Disabled') { return }
    Add-Entry @{ Kind = 'Task'; Path = $TPath; Name = $TName }
    Disable-ScheduledTask -TaskPath $TPath -TaskName $TName -ErrorAction SilentlyContinue | Out-Null
}

function Set-Bcd([string]$Name, [string]$Value) {
    $cur = (bcdedit /enum '{current}' | Select-String -Pattern "^$Name\s+(\S+)").Matches.Groups
    $old = if ($cur.Count -gt 1) { $cur[1].Value } else { $null }
    Add-Entry @{ Kind = 'Bcd'; Name = $Name; Value = $old }
    bcdedit /set '{current}' $Name $Value | Out-Null
}

function Set-Power([string]$Sub, [string]$Setting, [int]$Value) {
    # Valeur AC uniquement (secteur). Rend le parametre visible dans l'interface.
    powercfg -attributes $Sub $Setting -ATTRIB_HIDE 2>$null | Out-Null
    powercfg -setacvalueindex scheme_current $Sub $Setting $Value 2>$null | Out-Null
}

function Remove-App([string]$Name) {
    Get-AppxPackage -Name $Name -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object DisplayName -like $Name |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

function Install-Winget([string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { $Script:Warnings.Add("winget absent : $Id non installe"); return }
    winget install --id $Id -e --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null
}

function Step([string]$Title) { Write-Host "-> $Title" -ForegroundColor Yellow }

# ══════════════════════════════════════════════════════════════════════════════
#  GROUPES D'OPTIMISATION
# ══════════════════════════════════════════════════════════════════════════════

# ── Alimentation et ordonnanceur CPU ─────────────────────────────────────────
function Invoke-Power {
    Step 'Alimentation et ordonnanceur CPU'
    $prev = (powercfg -getactivescheme) -replace '.*([a-f0-9-]{36}).*', '$1'
    Add-Entry @{ Kind = 'PowerScheme'; Guid = $prev }

    # Performances ultimes (copie du modele cache), sinon Hautes performances
    $out = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1) -join ''
    if ($out -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') { powercfg -setactive $matches[1] | Out-Null }
    else { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null }

    Set-Power 54533251-82be-4824-96c1-47b60b740d00 0cc5b647-c1df-4637-891a-dec35c318583 100  # Core parking off (min coeurs actifs 100 %)
    Set-Power 54533251-82be-4824-96c1-47b60b740d00 893dee8e-2bef-41e0-89c6-b55d0929964c 100  # Etat CPU min 100 %
    Set-Power 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 2    # Boost agressif
    Set-Power 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0    # USB selective suspend off
    Set-Power 501a4d13-42af-4429-9fd1-a8218c268e20 ee12f906-d277-404b-b6da-e5fa1a576df5 0    # PCIe ASPM off
    Set-Power 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0    # Disque jamais eteint
    powercfg -setactive scheme_current | Out-Null
    powercfg -change -standby-timeout-ac 0 | Out-Null
    powercfg -h off 2>$null | Out-Null

    # Power Throttling (EcoQoS) : le noyau ne bride plus les processus en arriere-plan
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
    # Quantum : courts, variables, premier plan favorise (0x26)
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 0x26
    # Resolution du timer : comportement global restaure (Win 11 l'isole par processus)
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' 1
    # MMCSS : reserve CPU arriere-plan minimale (10 % = plancher effectif)
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'SystemResponsiveness' 10
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff
    $games = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'
    Set-Reg $games 'GPU Priority' 8
    Set-Reg $games 'Priority' 6
    Set-Reg $games 'Scheduling Category' 'High' 'String'
    Set-Reg $games 'SFIO Priority' 'High' 'String'
}

# ── GPU, affichage, jeu ──────────────────────────────────────────────────────
function Invoke-Gpu {
    Step 'GPU, interruptions et jeu'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2               # HAGS
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm' 'OverlayTestMode' 5                           # MPO off (saccades, ecrans noirs)
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0                                    # Enregistrement en arriere-plan off
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0

    # Mode MSI (Message Signaled Interrupts) pour GPU, reseau, stockage NVMe/USB
    $devices = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -like 'PCI\*' -and $_.Class -in @('Display', 'Net', 'SCSIAdapter', 'HDC', 'USB') }
    foreach ($d in $devices) {
        $p = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($d.InstanceId)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        Set-Reg $p 'MSISupported' 1
    }
}

# ── Memoire et disque ────────────────────────────────────────────────────────
function Invoke-Storage {
    Step 'Memoire et stockage'
    Set-Svc 'SysMain'                                                    # Superfetch : inutile sur SSD
    fsutil behavior set disablelastaccess 1 2>$null | Out-Null           # Pas d'ecriture a chaque lecture
    fsutil behavior set disable8dot3 1 2>$null | Out-Null
    fsutil behavior set DisableDeleteNotify 0 2>$null | Out-Null         # TRIM actif
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'NtfsMemoryUsage' 2
    # Compression memoire : off avec 16 Go+, sinon conservee
    $ramGb = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    if ($ramGb -ge 16) { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue }
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0
    Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout' '1000' 'String'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' 'String'
}

# ── Services et taches de fond ───────────────────────────────────────────────
function Invoke-Services {
    Step 'Services et taches de fond'
    foreach ($s in 'DiagTrack', 'dmwappushservice', 'WerSvc', 'PcaSvc', 'MapsBroker', 'lfsvc', 'RetailDemo',
                   'RemoteRegistry', 'TrkWks', 'AJRouter', 'Fax', 'WMPNetworkSvc', 'wisvc', 'DPS', 'WdiServiceHost',
                   'WdiSystemHost', 'diagsvc', 'DusmSvc', 'PhoneSvc', 'SEMgrSvc', 'stisvc') {
        Set-Svc $s
    }
    foreach ($s in 'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc', 'BITS', 'WSearch') { Set-Svc $s 'Manual' }

    $tasks = @(
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
        @('\Microsoft\Windows\Application Experience\', 'StartupAppTask'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
        @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload'),
        @('\Microsoft\Windows\Windows Error Reporting\', 'QueueReporting'),
        @('\Microsoft\Windows\CloudExperienceHost\', 'CreateObjectTask'),
        @('\Microsoft\Windows\PI\', 'Sqm-Tasks'),
        @('\Microsoft\Windows\NetTrace\', 'GatherNetworkInfo'),
        @('\Microsoft\Windows\Maintenance\', 'WinSAT'),
        @('\Microsoft\Windows\Power Efficiency Diagnostics\', 'AnalyzeSystem'),
        @('\Microsoft\Windows\Shell\', 'FamilySafetyMonitor'),
        @('\Microsoft\Windows\Shell\', 'FamilySafetyRefreshTask'),
        @('\Microsoft\Windows\Defrag\', 'ScheduledDefrag'),
        @('\Microsoft\Windows\Maps\', 'MapsUpdateTask'),
        @('\Microsoft\Windows\Maps\', 'MapsToastTask')
    )
    foreach ($t in $tasks) { Disable-Task $t[0] $t[1] }
    # Defrag planifie remplace par un TRIM hebdomadaire leger
    schtasks /Create /TN 'win-11\TRIM' /TR 'defrag.exe /C /L' /SC WEEKLY /RU SYSTEM /F 2>$null | Out-Null

    # Applications en arriere-plan
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
}

# ── Defender allege (profil normal) ──────────────────────────────────────────
function Invoke-DefenderLight {
    Step 'Defender allege (protection conservee)'
    # Limite CPU des analyses, priorite basse, analyses seulement au repos
    Set-MpPreference -ScanAvgCPULoadFactor 15 -EnableLowCpuPriority $true -ScanOnlyIfIdleEnabled $true `
        -DisableCatchupFullScan $true -DisableCatchupQuickScan $true -SubmitSamplesConsent 2 `
        -DisableArchiveScanning $true -ErrorAction SilentlyContinue
    # Exclusions : dossiers de compilation et bibliotheques de jeux
    $paths = @("$env:USERPROFILE\source", "$env:USERPROFILE\.cargo", "$env:USERPROFILE\.gradle", "$env:USERPROFILE\.nuget",
               "$env:LOCALAPPDATA\npm-cache", "${env:ProgramFiles(x86)}\Steam\steamapps", "$env:ProgramFiles\Epic Games")
    foreach ($p in $paths) { if (Test-Path $p) { Add-MpPreference -ExclusionPath $p -ErrorAction SilentlyContinue } }
    Add-MpPreference -ExclusionProcess 'cl.exe', 'link.exe', 'rustc.exe', 'cargo.exe', 'node.exe', 'java.exe', 'msbuild.exe' -ErrorAction SilentlyContinue
    foreach ($n in 'Windows Defender Cache Maintenance', 'Windows Defender Cleanup', 'Windows Defender Verification') {
        Disable-Task '\Microsoft\Windows\Windows Defender\' $n
    }
}

# ── Debloat ──────────────────────────────────────────────────────────────────
function Invoke-Debloat {
    Step 'Suppression des applications'
    $apps = 'Clipchamp.Clipchamp', 'Microsoft.549981C3F5F10', 'Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.BingWeather',
            'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.MicrosoftStickyNotes', 'Microsoft.MixedReality.Portal', 'Microsoft.Office.OneNote', 'Microsoft.OneConnect',
            'Microsoft.OutlookForWindows', 'Microsoft.People', 'Microsoft.PowerAutomateDesktop', 'Microsoft.SkypeApp', 'Microsoft.Todos',
            'Microsoft.WindowsAlarms', 'Microsoft.WindowsCommunicationsApps', 'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps',
            'Microsoft.WindowsSoundRecorder', 'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo',
            'Microsoft.Windows.DevHome', 'MicrosoftTeams', 'MSTeams', 'Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider',
            'MicrosoftCorporationII.QuickAssist', 'Microsoft.Windows.Recall'
    # Les apps Xbox restent : necessaires au Game Pass et a certains jeux
    foreach ($a in $apps) { Remove-App $a }
    Remove-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -ErrorAction SilentlyContinue
    # Recall et IA locale
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    $cdm = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($n in 'SilentInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled',
                   'SoftLandingEnabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                   'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled',
                   'SubscribedContent-353698Enabled') { Set-Reg $cdm $n 0 }
}

# ── Confidentialite ──────────────────────────────────────────────────────────
function Invoke-Privacy {
    Step 'Telemetrie et confidentialite'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsMSACloudSearchEnabled' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsAADCloudSearchEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsSpotlightFeatures' 1
    Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_TrackProgs' 0
}

# ── Confort (fonctions natives utiles) ───────────────────────────────────────
function Invoke-Comfort {
    Step 'Confort : Snap, fin de tache, volume par application'
    $adv = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    # Alignement des fenetres (Snap) complet
    Set-Reg 'HKCU:\Control Panel\Desktop' 'WindowArrangementActive' '1' 'String'
    Set-Reg $adv 'SnapAssist' 1
    Set-Reg $adv 'EnableSnapAssistFlyout' 1
    Set-Reg $adv 'EnableSnapBar' 1
    Set-Reg $adv 'SnapFill' 1
    Set-Reg $adv 'JointResize' 1
    # "Fin de tache" au clic droit dans la barre des taches
    Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1
    # Explorateur : extensions et fichiers caches visibles, widgets et chat off
    Set-Reg $adv 'HideFileExt' 0
    Set-Reg $adv 'Hidden' 1
    Set-Reg $adv 'TaskbarDa' 0
    Set-Reg $adv 'TaskbarMn' 0
    Set-Reg $adv 'LaunchTo' 1
    Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
    # Souris : acceleration off (vise constante)
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
    # Effets visuels : animations off, lissage des polices conserve
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 3
    Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-Reg $adv 'TaskbarAnimations' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
    # Volume par application : EarTrumpet (MIT) ; Windhawk pour le defilement sur l'icone
    Install-Winget 'File-New-Project.EarTrumpet'
    Install-Winget 'RamenSoftware.Windhawk'
    $Script:Warnings.Add('Volume au survol de l''icone : ouvrir Windhawk > installer le mod "Taskbar Volume Control Per-App".')
}

# ── Theme OLED ───────────────────────────────────────────────────────────────
function Invoke-Oled {
    Step 'Theme OLED (noir pur)'
    $p = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-Reg $p 'AppsUseLightTheme' 0
    Set-Reg $p 'SystemUsesLightTheme' 0
    Set-Reg $p 'EnableTransparency' 0
    Set-Reg $p 'ColorPrevalence' 0
    $dir = "$env:LOCALAPPDATA\Microsoft\Windows\Themes"
    New-Item $dir -ItemType Directory -Force | Out-Null
    $bmp = "$dir\oled-noir.bmp"
    [IO.File]::WriteAllBytes($bmp, [byte[]](0x42,0x4D,0x3A,0,0,0,0,0,0,0,0x36,0,0,0,0x28,0,0,0,1,0,0,0,1,0,0,0,1,0,0x18,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    Set-Reg 'HKCU:\Control Panel\Desktop' 'Wallpaper' $bmp 'String'
    Set-Reg 'HKCU:\Control Panel\Colors' 'Background' '0 0 0' 'String'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'LockScreenImage' $bmp 'String'
    # Ecran de veille noir court : evite le marquage des pixels fixes
    Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaveActive' '1' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'ScreenSaveTimeOut' '300' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'SCRNSAVE.EXE' "$env:SystemRoot\System32\scrnsave.scr" 'String'
    # Barre des taches masquee automatiquement (pixels statiques)
    try {
        $k = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'
        $s = (Get-ItemProperty $k -Name Settings -ErrorAction Stop).Settings
        Add-Entry @{ Kind = 'Reg'; Path = $k; Name = 'Settings'; Existed = $true; Value = [Convert]::ToBase64String($s); Type = 'Binary' }
        $s[8] = $s[8] -bor 0x01
        Set-ItemProperty $k -Name Settings -Value $s
    } catch {}
}

# ── Navigateurs (optionnel) ──────────────────────────────────────────────────
function Invoke-Browsers {
    Step 'Navigateurs : Firefox, Brave, Tor ; Edge retire'
    Install-Winget 'Mozilla.Firefox'
    Install-Winget 'Brave.Brave'
    Install-Winget 'TorProject.TorBrowser'
    if (Test-Path "$env:ProgramFiles\Mozilla Firefox\firefox.exe") {
        $setup = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Edge\Application" -Recurse -Filter setup.exe -ErrorAction SilentlyContinue | Select-Object -Last 1
        if ($setup) { & $setup.FullName --uninstall --system-level --force-uninstall 2>$null | Out-Null }
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium' 1
        # WebView2 conserve : requis par de nombreuses applications
    } else { $Script:Warnings.Add('Firefox absent : Edge conserve pour ne pas laisser le systeme sans navigateur.') }
}

# ── Extreme ──────────────────────────────────────────────────────────────────
function Invoke-Extreme {
    Step 'EXTREME : VBS, mitigations, hyperviseur, Defender'
    # Virtualisation de la securite et integrite memoire
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'LsaCfgFlags' 0
    Set-Bcd 'hypervisorlaunchtype' 'off'
    # Mitigations Spectre / Meltdown au niveau noyau
    $mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    Set-Reg $mm 'FeatureSettingsOverride' 3
    Set-Reg $mm 'FeatureSettingsOverrideMask' 3
    # Defender : necessite la Protection contre les falsifications desactivee a la main
    $tamper = (Get-MpComputerStatus -ErrorAction SilentlyContinue).IsTamperProtected
    if ($tamper) {
        $Script:Warnings.Add('Defender non desactive : coupez "Protection contre les falsifications" (Securite Windows > Virus) puis relancez avec -Extreme.')
    } else {
        Set-MpPreference -DisableRealtimeMonitoring $true -MAPSReporting 0 -ErrorAction SilentlyContinue
        $pol = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
        Set-Reg $pol 'DisableAntiSpyware' 1
        Set-Reg "$pol\Real-Time Protection" 'DisableRealtimeMonitoring' 1
        Set-Reg "$pol\Real-Time Protection" 'DisableBehaviorMonitoring' 1
        Set-Reg "$pol\Spynet" 'SpynetReporting' 0
        foreach ($s in 'WinDefend', 'WdNisSvc', 'Sense') { Set-Svc $s }
        Disable-Task '\Microsoft\Windows\Windows Defender\' 'Windows Defender Scheduled Scan'
        # Analyse a la demande open source (GPLv2) : pas de protection temps reel
        Install-Winget 'Cisco.ClamAV'
        $Script:Warnings.Add('Defender coupe. ClamAV installe : analyse manuelle uniquement (clamscan), aucune protection en temps reel.')
    }
    $Script:Warnings.Add('Extreme : WSL2, Hyper-V, Docker Desktop et le Sandbox Windows ne fonctionnent plus jusqu''a -Restore.')
}

# ── Windows Update ───────────────────────────────────────────────────────────
function Invoke-UpdatePolicy {
    Step 'Windows Update : securite oui, pilotes et redemarrages forces non'
    $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    Set-Reg $au 'ExcludeWUDriversInQualityUpdate' 1
    Set-Reg "$au\AU" 'NoAutoRebootWithLoggedOnUsers' 1
    Set-Reg "$au\AU" 'AUOptions' 3
    Set-Reg $au 'DeferFeatureUpdates' 1
    Set-Reg $au 'DeferFeatureUpdatesPeriodInDays' 180
}

# ══════════════════════════════════════════════════════════════════════════════
#  RESTAURATION
# ══════════════════════════════════════════════════════════════════════════════
function Invoke-Restore([string]$File) {
    if (-not $File) {
        $File = Get-ChildItem "$Script:DataDir\journal-*.json" -ErrorAction SilentlyContinue | Sort-Object Name | Select-Object -Last 1 -ExpandProperty FullName
    }
    if (-not $File -or -not (Test-Path $File)) { Write-Host 'Aucun journal trouve.' -ForegroundColor Red; return }
    Write-Host "Restauration depuis $File" -ForegroundColor Cyan
    $items = @(Get-Content $File -Raw | ConvertFrom-Json)
    [array]::Reverse($items)
    foreach ($e in $items) {
        switch ($e.Kind) {
            'Reg' {
                if (-not $e.Existed) { Remove-ItemProperty -Path $e.Path -Name $e.Name -ErrorAction SilentlyContinue; continue }
                $v = if ($e.Type -eq 'Binary') { [Convert]::FromBase64String($e.Value) } else { $e.Value }
                $t = if ($e.Type -in 'String', 'ExpandString', 'Binary', 'DWord', 'QWord', 'MultiString') { $e.Type } else { 'DWord' }
                if (-not (Test-Path $e.Path)) { New-Item $e.Path -Force | Out-Null }
                New-ItemProperty -Path $e.Path -Name $e.Name -Value $v -PropertyType $t -Force -ErrorAction SilentlyContinue | Out-Null
            }
            'Svc'  { if ($null -ne $e.Start) { Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($e.Name)" -Name Start -Value $e.Start -ErrorAction SilentlyContinue } }
            'Task' { Enable-ScheduledTask -TaskPath $e.Path -TaskName $e.Name -ErrorAction SilentlyContinue | Out-Null }
            'Bcd'  { if ($e.Value) { bcdedit /set '{current}' $e.Name $e.Value | Out-Null } else { bcdedit /deletevalue '{current}' $e.Name | Out-Null } }
            'PowerScheme' { powercfg -setactive $e.Guid | Out-Null }
        }
    }
    Enable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue
    schtasks /Delete /TN 'win-11\TRIM' /F 2>$null | Out-Null
    Write-Host 'Restauration terminee. Redemarrez. (Les applications supprimees se reinstallent depuis le Store.)' -ForegroundColor Green
}

# Ordre d'execution et descriptions (menu Personnalise)
$Script:GroupList = @(
    @{ Id = 'Power';         Desc = 'Alimentation, core parking, timer, priorites CPU' }
    @{ Id = 'Gpu';           Desc = 'HAGS, MPO off, Game DVR off, interruptions MSI' }
    @{ Id = 'Storage';       Desc = 'SysMain, NTFS, TRIM, compression memoire' }
    @{ Id = 'Services';      Desc = 'Services et taches de fond inutiles' }
    @{ Id = 'UpdatePolicy';  Desc = 'Windows Update sans pilotes ni redemarrage force' }
    @{ Id = 'DefenderLight'; Desc = 'Defender allege (protection conservee)' }
    @{ Id = 'Debloat';       Desc = 'Applications, Copilot, Recall' }
    @{ Id = 'Privacy';       Desc = 'Telemetrie et confidentialite' }
    @{ Id = 'Comfort';       Desc = 'Snap, fin de tache, volume par application' }
    @{ Id = 'Oled';          Desc = 'Theme noir pur pour ecran OLED' }
    @{ Id = 'Browsers';      Desc = 'Firefox, Brave, Tor ; Edge retire' }
    @{ Id = 'Extreme';       Desc = 'VBS, mitigations, hyperviseur, Defender off' }
)

# ══════════════════════════════════════════════════════════════════════════════
#  MENU ET EXECUTION
# ══════════════════════════════════════════════════════════════════════════════
if ($Restore) { Invoke-Restore $Journal; exit }

if (-not $Profil) {
    Clear-Host
    Write-Host ''
    Write-Host "  win-11 v$Script:Version  |  github.com/matglitch-974/win-11" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  1  Systeme        performances uniquement, rien de visuel ni d''applications'
    Write-Host '  2  Complet        Systeme + debloat + confidentialite + confort'
    Write-Host '  3  Complet OLED   Complet + theme noir pur pour ecran OLED'
    Write-Host '  4  Personnalise   choix groupe par groupe (console ou interface graphique)'
    Write-Host '  R  Restaurer      annule la derniere optimisation'
    Write-Host ''
    switch ((Read-Host '  Choix').Trim().ToUpper()) {
        '1' { $Profil = 'Systeme' }
        '2' { $Profil = 'Complet' }
        '3' { $Profil = 'CompletOLED' }
        '4' { $Profil = 'Personnalise' }
        'R' { Invoke-Restore $null; exit }
        default { exit }
    }
}

if ($Profil -eq 'Personnalise') {
    Write-Host ''
    Write-Host '  1  Console'
    Write-Host '  2  Interface graphique (base Win11Debloat de Raphire)'
    if ((Read-Host '  Choix').Trim() -eq '2') {
        $gui = Join-Path $PSScriptRoot 'gui\Win11Debloat.ps1'
        if (-not (Test-Path $gui)) { Write-Host '  Dossier gui introuvable : lancez depuis le depot complet.' -ForegroundColor Red; exit 1 }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $gui
        exit
    }
    Write-Host ''
    $i = 0
    foreach ($g in $Script:GroupList) { $i++; Write-Host ("  {0,2}  {1,-14} {2}" -f $i, $g.Id, $g.Desc) }
    Write-Host ''
    $sel = Read-Host '  Numeros separes par des virgules (ex : 1,2,3,8)'
    $ids = foreach ($n in ($sel -split '[,; ]+' | Where-Object { $_ -match '^\d+$' })) {
        $idx = [int]$n - 1
        if ($idx -ge 0 -and $idx -lt $Script:GroupList.Count) { $Script:GroupList[$idx].Id }
    }
    if (-not $ids) { exit }
    $Groupes = $ids -join ','
}

if (-not $Groupes -and -not $Silencieux -and $PSBoundParameters.Count -eq 0) {
    Write-Host ''
    Write-Host '  Mode EXTREME : VBS, mitigations CPU et Defender coupes. Gain de 5 a 15 % en jeu,' -ForegroundColor DarkYellow
    Write-Host '  securite reduite, WSL2/Hyper-V/Docker inutilisables.' -ForegroundColor DarkYellow
    if ((Read-Host '  Activer ? (o/N)') -match '^[oOyY]') { $Extreme = $true }
    if ((Read-Host '  Remplacer Edge par Firefox/Brave/Tor ? (o/N)') -match '^[oOyY]') { $Navigateurs = $true }
}

# Profils -> groupes
if (-not $Groupes) {
    $list = @('Power', 'Gpu', 'Storage', 'Services', 'UpdatePolicy')
    if (-not $Extreme) { $list += 'DefenderLight' }
    if ($Profil -in 'Complet', 'CompletOLED') { $list += 'Debloat', 'Privacy', 'Comfort' }
    if ($Profil -eq 'CompletOLED') { $list += 'Oled' }
    if ($Navigateurs) { $list += 'Browsers' }
    if ($Extreme)     { $list += 'Extreme' }
    $Groupes = $list -join ','
}
$selected = @($Groupes -split '[,; ]+' | Where-Object { $_ })
$unknown  = $selected | Where-Object { $_ -notin $Script:GroupList.Id }
if ($unknown) { Write-Host "Groupe(s) inconnu(s) : $($unknown -join ', ')" -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host "  Groupes : $($selected -join ', ')" -ForegroundColor Cyan

# Point de restauration systeme (filet supplementaire au journal)
try {
    Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
    Checkpoint-Computer -Description "win-11 avant $Profil" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
} catch { $Script:Warnings.Add('Point de restauration systeme non cree (le journal win-11 reste disponible).') }

foreach ($g in $Script:GroupList) { if ($g.Id -in $selected) { & "Invoke-$($g.Id)" } }

Save-Journal

if (-not $SansMisesAJour -and -not $Silencieux) {
    Step 'Recherche des mises a jour'
    try {
        $s = New-Object -ComObject Microsoft.Update.Session
        $r = $s.CreateUpdateSearcher().Search("IsInstalled=0 and Type='Software' and IsHidden=0")
        if ($r.Updates.Count -gt 0) {
            $d = $s.CreateUpdateDownloader(); $d.Updates = $r.Updates; $d.Download() | Out-Null
            $i = $s.CreateUpdateInstaller(); $i.Updates = $r.Updates; $i.Install() | Out-Null
        }
    } catch { $Script:Warnings.Add('Windows Update inaccessible.') }
}

Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Write-Host ''
foreach ($w in $Script:Warnings) { Write-Host "  ! $w" -ForegroundColor DarkYellow }
Write-Host ''
Write-Host '  Termine. Redemarrez pour appliquer (MSI, VBS, timer, services).' -ForegroundColor Green
Write-Host '  Annulation : .\win11.ps1 -Restore' -ForegroundColor DarkGray
if (-not $Silencieux) { Read-Host '  Entree pour fermer' | Out-Null }
