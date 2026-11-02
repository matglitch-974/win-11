#Requires -Version 5.1
# win-11 — allege Windows 11 en une commande
# https://github.com/matglitch-974/win-11
# Inspire de Win11Debloat par Raphire (MIT)

[CmdletBinding(SupportsShouldProcess)] param()

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'

# ── Auto-elevation ────────────────────────────────────────────────────────────
$self  = [Security.Principal.WindowsIdentity]::GetCurrent()
$admin = ([Security.Principal.WindowsPrincipal]$self).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $url = 'https://raw.githubusercontent.com/matglitch-974/win-11/main/run.ps1'
    $tmp = "$env:TEMP\win11-run.ps1"
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$tmp`""
    exit
}

# ── Helpers ───────────────────────────────────────────────────────────────────
function Remove-App([string]$Name) {
    try { Get-AppxPackage -Name $Name -AllUsers | Remove-AppxPackage -AllUsers } catch {}
    try { Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $Name | Remove-AppxProvisionedPackage -Online | Out-Null } catch {}
}

function Set-Reg([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord') {
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } catch {}
}

function Disable-Svc([string]$Name) {
    try { Stop-Service -Name $Name -Force }               catch {}
    try { Set-Service  -Name $Name -StartupType Disabled } catch {}
}

function Disable-Task([string]$TPath, [string]$TName) {
    try { Disable-ScheduledTask -TaskPath $TPath -TaskName $TName | Out-Null } catch {}
}

# ── Banner ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ''
Write-Host '  win-11  |  github.com/matglitch-974/win-11' -ForegroundColor Cyan
Write-Host ''

# ── 1. Bloatware ──────────────────────────────────────────────────────────────
Write-Host '[1/6] Suppression des applications bloatware...' -ForegroundColor Yellow

$apps = @(
    'Clipchamp.Clipchamp'
    'Microsoft.549981C3F5F10'
    'Microsoft.BingNews'
    'Microsoft.BingSearch'
    'Microsoft.BingWeather'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.MixedReality.Portal'
    'Microsoft.Office.OneNote'
    'Microsoft.OneConnect'
    'Microsoft.OutlookForWindows'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.SkypeApp'
    'Microsoft.Todos'
    'Microsoft.WindowsAlarms'
    'Microsoft.WindowsCommunicationsApps'
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxApp'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    'Microsoft.YourPhone'
    'Microsoft.ZuneMusic'
    'Microsoft.ZuneVideo'
    'Microsoft.Windows.DevHome'
    'MicrosoftTeams'
    'MSTeams'
)
foreach ($app in $apps) { Remove-App $app }
Write-Host '  OK' -ForegroundColor Green

# ── 2. Telemetrie & confidentialite ──────────────────────────────────────────
Write-Host '[2/7] Telemetrie, Bing, confidentialite et taches planifiees...' -ForegroundColor Yellow

Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'                'AllowTelemetry'                              0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'                              0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MaxTelemetryAllowed'                         0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'                 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'         'Enabled'                                     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'       'Start_TrackProgs'                            0
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'                      'DisableSearchBoxSuggestions'                 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'                'AllowCortana'                                0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'BingSearchEnabled'                           0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'CortanaConsent'                              0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'DisableWebSearch'                            1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'AllowSearchToUseLocation'                    0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'SafeSearchMode'                              0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'                'DisableWebSearch'                            1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'                'ConnectedSearchUseWeb'                       0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'                'ConnectedSearchUseWebOverMeteredConnections'  0

# Recherche cloud (compte Microsoft et AAD) -> off
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'          'IsAADCloudSearchEnabled'                     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'          'IsMSACloudSearchEnabled'                     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'          'IsDeviceSearchHistoryEnabled'                0

# Windows Spotlight (fonds d'ecran et suggestions Bing sur l'ecran de verrouillage et les parametres)
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableWindowsSpotlightFeatures'             1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableWindowsSpotlightOnActionCenter'       1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableWindowsSpotlightOnSettings'           1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableWindowsSpotlightWindowsWelcomeExperience' 1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableTailoredExperiencesWithDiagnosticData' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableWindowsConsumerFeatures'              1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'                  'DisableCloudOptimizedContent'                1

# Fil d'actualites Bing (widget barre des taches, en plus de TaskbarDa)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds'                 'EnableFeeds'                                 0

Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'                'TurnOffWindowsCopilot'                       1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'                'TurnOffWindowsCopilot'                       1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'EnableActivityFeed'                          0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'PublishUserActivities'                       0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'UploadUserActivities'                        0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'                                     'NumberOfSIUFInPeriod'                        0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'                'DoNotShowFeedbackNotifications'              1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'                'Disabled'                                    1

# Delivery optimization (P2P Windows Update) -> local seulement
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'          'DODownloadMode'                              1

# Taches planifiees : telemetrie Microsoft
Disable-Task '\Microsoft\Windows\Application Experience\'                  'Microsoft Compatibility Appraiser'
Disable-Task '\Microsoft\Windows\Application Experience\'                  'ProgramDataUpdater'
Disable-Task '\Microsoft\Windows\Application Experience\'                  'StartupAppTask'
Disable-Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'Consolidator'
Disable-Task '\Microsoft\Windows\Customer Experience Improvement Program\' 'UsbCeip'
Disable-Task '\Microsoft\Windows\DiskDiagnostic\'                          'Microsoft-Windows-DiskDiagnosticDataCollector'
Disable-Task '\Microsoft\Windows\Feedback\Siuf\'                           'DmClient'
Disable-Task '\Microsoft\Windows\Feedback\Siuf\'                           'DmClientOnScenarioDownload'
Disable-Task '\Microsoft\Windows\Windows Error Reporting\'                 'QueueReporting'
Disable-Task '\Microsoft\Windows\CloudExperienceHost\'                     'CreateObjectTask'
Disable-Task '\Microsoft\Windows\PI\'                                      'Sqm-Tasks'
Disable-Task '\Microsoft\Windows\NetTrace\'                                'GatherNetworkInfo'

# Taches planifiees : diagnostics et maintenance inutiles
Disable-Task '\Microsoft\Windows\Maintenance\'                             'WinSAT'
Disable-Task '\Microsoft\Windows\Power Efficiency Diagnostics\'            'AnalyzeSystem'
Disable-Task '\Microsoft\Windows\MemoryDiagnostic\'                        'ProcessMemoryDiagnosticEvents'
Disable-Task '\Microsoft\Windows\MemoryDiagnostic\'                        'RunFullMemoryDiagnostic'
Disable-Task '\Microsoft\Windows\Shell\'                                   'FamilySafetyMonitor'
Disable-Task '\Microsoft\Windows\Shell\'                                   'FamilySafetyRefreshTask'
Disable-Task '\Microsoft\Windows\DiskFootprint\'                           'Diagnostics'
Disable-Task '\Microsoft\Windows\DiskFootprint\'                           'StorageSense'
Disable-Task '\Microsoft\Windows\Windows Defender\'                        'Windows Defender Cache Maintenance'
Disable-Task '\Microsoft\Windows\Windows Defender\'                        'Windows Defender Cleanup'
Disable-Task '\Microsoft\Windows\Windows Defender\'                        'Windows Defender Scheduled Scan'
Disable-Task '\Microsoft\Windows\Windows Defender\'                        'Windows Defender Verification'

Write-Host '  OK' -ForegroundColor Green

# ── 3. Interface & applications background ───────────────────────────────────
Write-Host '[3/7] Interface, demarrage et applications background...' -ForegroundColor Yellow

Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                                  'AllowNewsAndInterests'           0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'      'TaskbarDa'                       0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'      'TaskbarMn'                       0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                 'SearchboxTaskbarMode'            1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'      'HideFileExt'                     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'      'Hidden'                          1
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'     'EnableTransparency'              0

# Suggestions et apps silencieuses
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353698Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled'    0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled'              0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled'      0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled'         0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled'     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled'      0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'  'ScoobeSystemSettingEnabled'      0

# Applications en arriere-plan : desactiver globalement
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy'                         'LetAppsRunInBackground' 2

# OneDrive : retirer du demarrage (sans desinstaller)
try { Remove-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -Force } catch {}

# Maintenance automatique Windows
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 1

Write-Host '  OK' -ForegroundColor Green

# ── 4. Services ───────────────────────────────────────────────────────────────
Write-Host '[4/7] Services...' -ForegroundColor Yellow

Disable-Svc 'DiagTrack'        # Telemetrie
Disable-Svc 'dmwappushservice' # WAP Push
Disable-Svc 'PcaSvc'           # Compat applications
Disable-Svc 'WerSvc'           # Rapport d'erreurs
Disable-Svc 'SysMain'          # Superfetch (inutile sur SSD)
Disable-Svc 'MapsBroker'       # Cartes hors ligne
Disable-Svc 'lfsvc'            # Geolocalisation
Disable-Svc 'RetailDemo'       # Mode demo magasin
Disable-Svc 'RemoteRegistry'   # Registre distant
Disable-Svc 'TrkWks'           # Tracking liens
Disable-Svc 'AJRouter'         # AllJoyn Router
Disable-Svc 'Fax'              # Telecopie
Disable-Svc 'XblAuthManager'   # Xbox Live Auth
Disable-Svc 'XblGameSave'      # Xbox Live Save
Disable-Svc 'XboxNetApiSvc'    # Xbox Live Net
Disable-Svc 'xbgm'             # Xbox Game Monitoring

Write-Host '  OK' -ForegroundColor Green

# ── 5. Performance systeme ────────────────────────────────────────────────────
Write-Host '[5/7] Performance systeme...' -ForegroundColor Yellow

# Plan d'alimentation : Performances ultimes (fallback : Haute performance)
try {
    $out = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1) -join ''
    if ($out -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
        powercfg -setactive $matches[1] | Out-Null
    } else {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null
    }
} catch { try { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null } catch {} }

# Parametres d'alimentation supplementaires
try {
    powercfg -change -disk-timeout-ac      0 | Out-Null  # Disque jamais eteint
    powercfg -change -standby-timeout-ac   0 | Out-Null  # Veille desactivee (mode AC)
    powercfg -change -hibernate-timeout-ac 0 | Out-Null  # Hibernation auto desactivee
} catch {}

# Hibernation off (libere de l'espace = taille de la RAM)
try { powercfg -h off 2>$null | Out-Null } catch {}

# Effets visuels -> Performances
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'  'VisualFXSetting'        2
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'       'ListviewAlphaSelect'    0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'       'ListviewShadow'         0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'       'TaskbarAnimations'      0
Set-Reg 'HKCU:\Control Panel\Desktop'                                             'DragFullWindows'        '0'  'String'
Set-Reg 'HKCU:\Control Panel\Desktop'                                             'MenuShowDelay'          '0'  'String'
Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics'                               'MinAnimate'             '0'  'String'
Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM'                                    'EnableAeroPeek'         0
Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM'                                    'AlwaysHibernateThumbnails' 0

# Arret rapide : tuer les apps/services bloques rapidement
Set-Reg 'HKCU:\Control Panel\Desktop' 'HungAppTimeout'       '1000' 'String'  # 5000 par defaut
Set-Reg 'HKCU:\Control Panel\Desktop' 'WaitToKillAppTimeout' '2000' 'String'  # 5000 par defaut
Set-Reg 'HKCU:\Control Panel\Desktop' 'AutoEndTasks'         '1'    'String'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'WaitToKillServiceTimeout' '2000' 'String'

# Delai demarrage des applications au boot -> 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec' 0

# Priorite processeur -> programmes au premier plan
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 2

# Gestion memoire
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'ClearPageFileAtShutdown' 0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'LargeSystemCache'        0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisablePagingExecutive'  1
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'                        'NtfsEncryptPagingFile'   0

# NTFS
try { fsutil behavior set disablelastaccess 1 2>$null | Out-Null } catch {}
try { fsutil behavior set disable8dot3 1 2>$null | Out-Null }      catch {}

# Hardware-Accelerated GPU Scheduling
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2

# Game Mode automatique
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'   1

# Acceleration de la souris -> off (precision constante, utile gaming)
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed'      '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'

Write-Host '  OK' -ForegroundColor Green

# ── 6. Reseau & gaming ────────────────────────────────────────────────────────
Write-Host '[7/7] Reseau et gaming...' -ForegroundColor Yellow

# Network throttling off
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff

# Priorites GPU et CPU pour les jeux
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'GPU Priority'        8
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Priority'            6
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Scheduling Category' 'High' 'String'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'SFIO Priority'       'High' 'String'

# Nagle desactive sur chaque interface reseau
Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' | ForEach-Object {
    try {
        Set-ItemProperty -Path $_.PSPath -Name 'TcpAckFrequency' -Value 1 -Type DWord -Force
        Set-ItemProperty -Path $_.PSPath -Name 'TCPNoDelay'       -Value 1 -Type DWord -Force
    } catch {}
}
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' 'TcpDelAckTicks' 0

# Cache DNS elargi
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'CacheHashTableBucketSize' 1
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'CacheHashTableSize'       384
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'MaxCacheEntryTtlLimit'    64000
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters' 'MaxSOACacheEntryTtlLimit' 301

Write-Host '  OK' -ForegroundColor Green

# ── 6. Navigateurs & nettoyage themes ────────────────────────────────────────
Write-Host '[6/7] Navigateurs et themes...' -ForegroundColor Yellow

# Internet Explorer : desactiver la fonctionnalite Windows
try { Disable-WindowsOptionalFeature -Online -FeatureName 'Internet-Explorer-Optional-amd64' -NoRestart | Out-Null } catch {}

# Edge : desinstaller via son propre setup
try {
    $setup = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft\Edge\Application" -Recurse -Filter 'setup.exe' -ErrorAction SilentlyContinue | Select-Object -Last 1
    if ($setup) { & $setup.FullName --uninstall --system-level --force-uninstall 2>$null | Out-Null }
} catch {}
# Edge AppX legacy (EdgeHTML)
try { Get-AppxPackage -Name 'Microsoft.MicrosoftEdge' -AllUsers | Remove-AppxPackage -AllUsers } catch {}
try { Get-AppxPackage -Name 'Microsoft.MicrosoftEdge.Stable' -AllUsers | Remove-AppxPackage -AllUsers } catch {}
# Bloquer la reinstallation automatique d'Edge par Windows Update
Set-Reg 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium' 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' 'UpdateDefault' 0

# Installer Firefox, Tor Browser, Brave via winget
$wg = Get-Command winget -ErrorAction SilentlyContinue
if ($wg) {
    $browsers = @(
        @{ Id = 'Mozilla.Firefox';        Name = 'Firefox'     }
        @{ Id = 'TorProject.TorBrowser';  Name = 'Tor Browser' }
        @{ Id = 'Brave.Brave';            Name = 'Brave'       }
    )
    foreach ($b in $browsers) {
        Write-Host "  Installation de $($b.Name)..." -ForegroundColor DarkGray
        try { winget install --id $b.Id --silent --accept-package-agreements --accept-source-agreements 2>$null | Out-Null } catch {}
    }
} else {
    Write-Host '  winget absent — navigateurs a installer manuellement' -ForegroundColor DarkYellow
}

# Fonds d'ecran 4K (200-300 MB)
Remove-Item 'C:\Windows\Web\4K\' -Recurse -Force -ErrorAction SilentlyContinue
# Fonds d'ecran thematiques (garder le dossier Windows de base)
Get-ChildItem 'C:\Windows\Web\Wallpaper\' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notin @('Windows') } |
    ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
# Ecran de verrouillage par defaut
Remove-Item 'C:\Windows\Web\Screen\*' -Force -ErrorAction SilentlyContinue

Write-Host '  OK' -ForegroundColor Green

# ── Redemarrage de l'Explorateur ─────────────────────────────────────────────
try { Stop-Process -Name explorer -Force; Start-Sleep -Milliseconds 800; Start-Process explorer } catch {}

Write-Host ''
Write-Host '  Termine. Redemarrez Windows pour finaliser.' -ForegroundColor Green
Write-Host '  github.com/matglitch-974/win-11' -ForegroundColor DarkGray
Write-Host ''
