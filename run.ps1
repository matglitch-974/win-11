#Requires -Version 5.1
# win-11 — allege Windows 11 en une commande
# https://github.com/matglitch-974/win-11
# Inspire de Win11Debloat par Raphire (MIT)

[CmdletBinding(SupportsShouldProcess)] param()

Set-StrictMode -Off
$ErrorActionPreference = 'SilentlyContinue'

# ── Auto-elevation ────────────────────────────────────────────────────────────
$self = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal]$self).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
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
    try { Stop-Service  -Name $Name -Force }       catch {}
    try { Set-Service   -Name $Name -StartupType Disabled } catch {}
}

# ── Banner ────────────────────────────────────────────────────────────────────
Clear-Host
Write-Host ''
Write-Host '  ██╗    ██╗██╗███╗   ██╗    ██╗  ██╗' -ForegroundColor Cyan
Write-Host '  ██║    ██║██║████╗  ██║    ╚██╗██╔╝' -ForegroundColor Cyan
Write-Host '  ██║ █╗ ██║██║██╔██╗ ██║     ╚███╔╝ ' -ForegroundColor Cyan
Write-Host '  ██║███╗██║██║██║╚██╗██║     ██╔██╗ ' -ForegroundColor Cyan
Write-Host '  ╚███╔███╔╝██║██║ ╚████║    ██╔╝ ██╗' -ForegroundColor Cyan
Write-Host '   ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝    ╚═╝  ╚═╝' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Allegement Windows 11 — github.com/matglitch-974/win-11' -ForegroundColor DarkGray
Write-Host ''

# ── 1. Applications bloatware ─────────────────────────────────────────────────
Write-Host '[1/4] Suppression des applications preinstallees...' -ForegroundColor Yellow

$apps = @(
    # Microsoft bloatware
    'Clipchamp.Clipchamp'
    'Microsoft.549981C3F5F10'          # Cortana standalone
    'Microsoft.BingNews'
    'Microsoft.BingWeather'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.MixedReality.Portal'
    'Microsoft.Office.OneNote'
    'Microsoft.OneConnect'
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
    # Nouveaux ajouts Win11 23H2+
    'MicrosoftTeams'
    'Microsoft.BingSearch'
    'Microsoft.OutlookForWindows'
    'Microsoft.Windows.DevHome'
    'MSTeams'
)

foreach ($app in $apps) {
    Write-Host "  $app" -ForegroundColor DarkGray
    Remove-App $app
}
Write-Host "  OK" -ForegroundColor Green

# ── 2. Telemetrie & confidentialite ──────────────────────────────────────────
Write-Host '[2/4] Telemetrie et confidentialite...' -ForegroundColor Yellow

# Niveau de telemetrie -> 0 (securite uniquement, Enterprise/Education) ou 1 (basique)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'           'AllowTelemetry'                        0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'                  0
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'MaxTelemetryAllowed'             0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'            'TailoredExperiencesWithDiagnosticDataEnabled' 0

# Publicite personnalisee
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'    'Enabled'                               0

# Suivi des lancements d'applications
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  'Start_TrackProgs'                      0

# Cortana & recherche Bing dans le menu Demarrer
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer'                 'DisableSearchBoxSuggestions'           1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'           'AllowCortana'                          0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'             'BingSearchEnabled'                     0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'             'CortanaConsent'                        0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'             'DisableWebSearch'                      1

# Copilot
Set-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'           'TurnOffWindowsCopilot'                 1
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'           'TurnOffWindowsCopilot'                 1

# Historique d'activites
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                   'EnableActivityFeed'                    0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                   'PublishUserActivities'                 0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'                   'UploadUserActivities'                  0

# Feedback Windows
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Siuf\Rules'                                'NumberOfSIUFInPeriod'                  0
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'           'DoNotShowFeedbackNotifications'        1

# Rapport d'erreurs Windows
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting'           'Disabled'                              1

Write-Host "  OK" -ForegroundColor Green

# ── 3. Interface & barre des taches ──────────────────────────────────────────
Write-Host '[3/4] Interface et barre des taches...' -ForegroundColor Yellow

# Widgets (fils d'actualite)
Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'                              'AllowNewsAndInterests'                 0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  'TaskbarDa'                             0

# Chat / Teams integre
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  'TaskbarMn'                             0

# Recherche dans la barre -> icone seulement
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'             'SearchboxTaskbarMode'                  1

# Extensions de fichiers visibles
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  'HideFileExt'                           0

# Fichiers/dossiers caches visibles
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'  'Hidden'                                1

# Contenu suggere dans Demarrer
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338388Enabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338389Enabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353698Enabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SystemPaneSuggestionsEnabled'      0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SoftLandingEnabled'                0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'OemPreInstalledAppsEnabled'        0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEnabled'           0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'PreInstalledAppsEverEnabled'       0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SilentInstalledAppsEnabled'        0

# Conseils et astuces au demarrage
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-338393Enabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353694Enabled'   0
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' 'SubscribedContent-353696Enabled'   0

# Experience de bienvenue
Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled'          0

Write-Host "  OK" -ForegroundColor Green

# ── 4. Services de telemetrie ─────────────────────────────────────────────────
Write-Host '[4/4] Services de telemetrie...' -ForegroundColor Yellow

Disable-Svc 'DiagTrack'         # Telemetrie et diagnostics connectes
Disable-Svc 'dmwappushservice'  # WAP Push Message Routing
Disable-Svc 'PcaSvc'            # Programme de compatibilite des applications

Write-Host "  OK" -ForegroundColor Green

# ── Fin ───────────────────────────────────────────────────────────────────────
try {
    Stop-Process -Name explorer -Force
    Start-Sleep -Milliseconds 800
    Start-Process explorer
} catch {}

Write-Host ''
Write-Host '  Termine. Redemarrez Windows pour finaliser.' -ForegroundColor Green
Write-Host '  github.com/matglitch-974/win-11' -ForegroundColor DarkGray
Write-Host ''
