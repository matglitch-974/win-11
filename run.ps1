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
    try { Stop-Service -Name $Name -Force }          catch {}
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
    'Microsoft.549981C3F5F10'              # Cortana standalone
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
    'Microsoft.WindowsCommunicationsApps'  # Mail & Calendrier
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
Write-Host '[2/6] Telemetrie et confidentialite...' -ForegroundColor Yellow

Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'                'AllowTelemetry'                             0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'                             0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MaxTelemetryAllowed'                        0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'                 'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'         'Enabled'                                    0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'       'Start_TrackProgs'                           0
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'                      'DisableSearchBoxSuggestions'                1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'                'AllowCortana'                               0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'BingSearchEnabled'                          0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'CortanaConsent'                             0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                  'DisableWebSearch'                           1
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'                'TurnOffWindowsCopilot'                      1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'                'TurnOffWindowsCopilot'                      1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'EnableActivityFeed'                         0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'PublishUserActivities'                      0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                        'UploadUserActivities'                       0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'                                     'NumberOfSIUFInPeriod'                       0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'                'DoNotShowFeedbackNotifications'             1
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'                'Disabled'                                   1

# Taches planifiees de telemetrie
Disable-Task '\Microsoft\Windows\Application Experience\'                     'Microsoft Compatibility Appraiser'
Disable-Task '\Microsoft\Windows\Application Experience\'                     'ProgramDataUpdater'
Disable-Task '\Microsoft\Windows\Application Experience\'                     'StartupAppTask'
Disable-Task '\Microsoft\Windows\Customer Experience Improvement Program\'    'Consolidator'
Disable-Task '\Microsoft\Windows\Customer Experience Improvement Program\'    'UsbCeip'
Disable-Task '\Microsoft\Windows\DiskDiagnostic\'                             'Microsoft-Windows-DiskDiagnosticDataCollector'
Disable-Task '\Microsoft\Windows\Feedback\Siuf\'                              'DmClient'
Disable-Task '\Microsoft\Windows\Feedback\Siuf\'                              'DmClientOnScenarioDownload'
Disable-Task '\Microsoft\Windows\Windows Error Reporting\'                    'QueueReporting'
Disable-Task '\Microsoft\Windows\CloudExperienceHost\'                        'CreateObjectTask'
Disable-Task '\Microsoft\Windows\PI\'                                         'Sqm-Tasks'
Disable-Task '\Microsoft\Windows\NetTrace\'                                   'GatherNetworkInfo'

Write-Host '  OK' -ForegroundColor Green

# ── 3. Interface & barre des taches ──────────────────────────────────────────
Write-Host '[3/6] Interface et barre des taches...' -ForegroundColor Yellow

Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                                       'AllowNewsAndInterests'         0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'           'TaskbarDa'                     0  # Widgets
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'           'TaskbarMn'                     0  # Chat
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'                      'SearchboxTaskbarMode'          1  # Icone seulement
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'           'HideFileExt'                   0  # Extensions visibles
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'           'Hidden'                        1  # Fichiers caches visibles
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'          'EnableTransparency'            0  # Transparence off
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-338388Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-338389Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-353698Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SystemPaneSuggestionsEnabled'  0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SoftLandingEnabled'            0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'OemPreInstalledAppsEnabled'    0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'PreInstalledAppsEnabled'       0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'PreInstalledAppsEverEnabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SilentInstalledAppsEnabled'    0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-338393Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-353694Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'      'SubscribedContent-353696Enabled' 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'       'ScoobeSystemSettingEnabled'    0

Write-Host '  OK' -ForegroundColor Green

# ── 4. Services ───────────────────────────────────────────────────────────────
Write-Host '[4/6] Services...' -ForegroundColor Yellow

Disable-Svc 'DiagTrack'        # Telemetrie
Disable-Svc 'dmwappushservice' # WAP Push
Disable-Svc 'PcaSvc'           # Compat applications
Disable-Svc 'WerSvc'           # Rapport d'erreurs
Disable-Svc 'MapsBroker'       # Cartes hors ligne
Disable-Svc 'lfsvc'            # Geolocalisation
Disable-Svc 'RetailDemo'       # Mode demo magasin
Disable-Svc 'RemoteRegistry'   # Registre distant
Disable-Svc 'TrkWks'           # Tracking liens
Disable-Svc 'AJRouter'         # AllJoyn Router
Disable-Svc 'XblAuthManager'   # Xbox Live Auth
Disable-Svc 'XblGameSave'      # Xbox Live Save
Disable-Svc 'XboxNetApiSvc'    # Xbox Live Net
Disable-Svc 'xbgm'             # Xbox Game Monitoring

Write-Host '  OK' -ForegroundColor Green

# ── 5. Performance systeme ────────────────────────────────────────────────────
Write-Host '[5/6] Performance systeme...' -ForegroundColor Yellow

# Plan d'alimentation : Performances ultimes (fallback : Haute performance)
try {
    $out = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1) -join ''
    if ($out -match '([a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12})') {
        powercfg -setactive $matches[1] | Out-Null
    } else {
        powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null  # High Performance
    }
} catch {
    try { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c | Out-Null } catch {}
}

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

# Priorite processeur -> programmes au premier plan
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'                  'Win32PrioritySeparation' 2

# Gestion memoire : kernel en RAM, pas de vidage fichier page a l'arret
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'ClearPageFileAtShutdown' 0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'LargeSystemCache'        0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' 'DisablePagingExecutive'  1

# NTFS : desactiver LastAccess et noms 8.3 (gain lecture/ecriture)
try { fsutil behavior set disablelastaccess 1 2>$null | Out-Null } catch {}
try { fsutil behavior set disable8dot3 1 2>$null | Out-Null } catch {}

# Hardware-Accelerated GPU Scheduling (HAGS)
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2

# Game Mode automatique
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'   1

Write-Host '  OK' -ForegroundColor Green

# ── 6. Reseau & gaming ────────────────────────────────────────────────────────
Write-Host '[6/6] Reseau et gaming...' -ForegroundColor Yellow

# Desactiver le throttling reseau (streaming, jeux en ligne)
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' 'NetworkThrottlingIndex' 0xffffffff

# Priorites GPU et CPU pour les jeux
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'GPU Priority'         8
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Priority'             6
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'Scheduling Category'  'High' 'String'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games' 'SFIO Priority'        'High' 'String'

# Nagle desactive sur chaque interface reseau (latence TCP reduite)
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

# ── Redemarrage de l'Explorateur ─────────────────────────────────────────────
try { Stop-Process -Name explorer -Force; Start-Sleep -Milliseconds 800; Start-Process explorer } catch {}

Write-Host ''
Write-Host '  Termine. Redemarrez Windows pour finaliser.' -ForegroundColor Green
Write-Host '  github.com/matglitch-974/win-11' -ForegroundColor DarkGray
Write-Host ''
