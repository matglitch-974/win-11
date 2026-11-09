#Requires -Version 5.1
<#
.SYNOPSIS
    Genere une ISO Windows 11 optimisee a partir de l'ISO officielle Microsoft.

.DESCRIPTION
    1. Copie l'ISO officielle, ne garde que l'edition choisie.
    2. Retire hors ligne les applications provisionnees (elles ne s'installent jamais).
    3. Pre-applique les reglages machine critiques (telemetrie, Copilot, contournement TPM).
    4. Embarque win11.ps1 + autounattend.xml : le moteur s'execute au premier logon
       avec le profil choisi, donc ISO et conversion d'un PC existant donnent le meme resultat.
    5. Reconstruit une ISO amorcable BIOS + UEFI avec oscdimg.

    Prerequis : Windows, administrateur, ~25 Go libres,
    oscdimg.exe (Windows ADK "Deployment Tools", ou place a cote du script).

.EXAMPLE
    .\build-iso.ps1 -Iso D:\Win11_25H2_French_x64.iso -Profil Complet
    .\build-iso.ps1 -Iso .\Win11.iso -Profil Systeme -Extreme -Edition 'Windows 11 Pro'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Iso,
    [ValidateSet('Systeme', 'Complet', 'CompletOLED')][string]$Profil = 'Complet',
    [switch]$Extreme,
    [switch]$Navigateurs,
    [string]$Edition = 'Windows 11 Pro',
    [string]$Sortie = "$PSScriptRoot\win-11.iso",
    [string]$Travail = "$env:SystemDrive\win11-build"
)

$ErrorActionPreference = 'Stop'
function Step([string]$t) { Write-Host "-> $t" -ForegroundColor Yellow }

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole('Administrators')) {
    throw 'Lancer en administrateur.'
}
foreach ($f in 'win11.ps1', 'autounattend.xml') {
    if (-not (Test-Path "$PSScriptRoot\$f")) { throw "$f introuvable a cote de build-iso.ps1." }
}

# ── oscdimg ──────────────────────────────────────────────────────────────────
$oscdimg = @(
    "$PSScriptRoot\oscdimg.exe",
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $oscdimg) {
    throw "oscdimg.exe introuvable. Installer le Windows ADK (composant 'Deployment Tools') : winget install Microsoft.WindowsADK"
}

$iso   = (Resolve-Path $Iso).Path
$media = "$Travail\media"
$mount = "$Travail\mount"
if (Test-Path $Travail) { Remove-Item $Travail -Recurse -Force }
New-Item $media, $mount -ItemType Directory -Force | Out-Null

try {
    # ── 1. Copie du support ──────────────────────────────────────────────────
    Step 'Copie du support officiel'
    $img = Mount-DiskImage -ImagePath $iso -PassThru
    $drv = ($img | Get-Volume).DriveLetter + ':'
    Copy-Item "$drv\*" $media -Recurse -Force
    Dismount-DiskImage -ImagePath $iso | Out-Null
    Get-ChildItem $media -Recurse | ForEach-Object { $_.Attributes = $_.Attributes -band -bnot [IO.FileAttributes]::ReadOnly }

    # install.esd -> install.wim, une seule edition
    $src = if (Test-Path "$media\sources\install.wim") { "$media\sources\install.wim" } else { "$media\sources\install.esd" }
    $images = Get-WindowsImage -ImagePath $src
    $index  = ($images | Where-Object ImageName -eq $Edition).ImageIndex
    if (-not $index) { throw "Edition '$Edition' absente. Disponibles : $($images.ImageName -join ', ')" }
    Step "Extraction de '$Edition' (index $index)"
    $wim = "$Travail\install.wim"
    Export-WindowsImage -SourceImagePath $src -SourceIndex $index -DestinationImagePath $wim -CompressionType max | Out-Null
    Remove-Item $src -Force

    # ── 2. Montage et retrait des applications ───────────────────────────────
    Step 'Montage de l''image'
    Mount-WindowsImage -ImagePath $wim -Index 1 -Path $mount | Out-Null

    if ($Profil -ne 'Systeme') {
        Step 'Retrait hors ligne des applications provisionnees'
        $remove = 'Clipchamp.Clipchamp', 'Microsoft.549981C3F5F10', 'Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.BingWeather',
                  'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
                  'Microsoft.MicrosoftStickyNotes', 'Microsoft.OutlookForWindows', 'Microsoft.People', 'Microsoft.PowerAutomateDesktop',
                  'Microsoft.Todos', 'Microsoft.WindowsAlarms', 'microsoft.windowscommunicationsapps', 'Microsoft.WindowsFeedbackHub',
                  'Microsoft.WindowsMaps', 'Microsoft.WindowsSoundRecorder', 'Microsoft.YourPhone', 'Microsoft.ZuneMusic',
                  'Microsoft.ZuneVideo', 'Microsoft.Windows.DevHome', 'MSTeams', 'Microsoft.Copilot', 'MicrosoftCorporationII.QuickAssist'
        Get-AppxProvisionedPackage -Path $mount | Where-Object { $_.DisplayName -in $remove } | ForEach-Object {
            Write-Host "   - $($_.DisplayName)" -ForegroundColor DarkGray
            Remove-AppxProvisionedPackage -Path $mount -PackageName $_.PackageName | Out-Null
        }
    }

    # ── 3. Reglages pre-appliques (ruches hors ligne) ────────────────────────
    Step 'Reglages hors ligne'
    reg load HKLM\W11_SOFT "$mount\Windows\System32\config\SOFTWARE" | Out-Null
    reg load HKLM\W11_DEF  "$mount\Users\Default\NTUSER.DAT" | Out-Null
    try {
        $cmds = @(
            'HKLM\W11_SOFT\Policies\Microsoft\Windows\DataCollection /v AllowTelemetry /t REG_DWORD /d 0',
            'HKLM\W11_SOFT\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1',
            'HKLM\W11_SOFT\Policies\Microsoft\Windows\WindowsCopilot /v TurnOffWindowsCopilot /t REG_DWORD /d 1',
            'HKLM\W11_SOFT\Microsoft\Windows\CurrentVersion\OOBE /v BypassNRO /t REG_DWORD /d 1',
            'HKLM\W11_DEF\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v SilentInstalledAppsEnabled /t REG_DWORD /d 0',
            'HKLM\W11_DEF\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v PreInstalledAppsEnabled /t REG_DWORD /d 0',
            'HKLM\W11_DEF\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager /v OemPreInstalledAppsEnabled /t REG_DWORD /d 0'
        )
        foreach ($c in $cmds) { cmd /c "reg add $c /f" | Out-Null }
        # Empeche la reinstallation des apps a la mise a niveau
        cmd /c 'reg delete "HKLM\W11_SOFT\Microsoft\Windows\CurrentVersion\Communications" /v ConfigureChatAutoInstall /f' 2>$null | Out-Null
    } finally {
        [GC]::Collect(); Start-Sleep 1
        reg unload HKLM\W11_DEF  | Out-Null
        reg unload HKLM\W11_SOFT | Out-Null
    }

    # ── 4. Moteur embarque ───────────────────────────────────────────────────
    Step 'Integration du moteur win11.ps1'
    $scripts = "$mount\Windows\Setup\Scripts"
    New-Item $scripts -ItemType Directory -Force | Out-Null
    Copy-Item "$PSScriptRoot\win11.ps1" $scripts -Force

    $moteurArgs = "-Profil $Profil"
    if ($Extreme)     { $moteurArgs += ' -Extreme' }
    if ($Navigateurs) { $moteurArgs += ' -Navigateurs' }
    (Get-Content "$PSScriptRoot\autounattend.xml" -Raw).Replace('__WIN11_ARGS__', $moteurArgs) |
        Out-File "$media\autounattend.xml" -Encoding UTF8 -Force

    # Composants remplaces, puis demontage
    Step 'Nettoyage des composants (ResetBase)'
    dism /Image:$mount /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
    Dismount-WindowsImage -Path $mount -Save | Out-Null

    Step 'Recompression de l''image'
    Export-WindowsImage -SourceImagePath $wim -SourceIndex 1 -DestinationImagePath "$media\sources\install.wim" -CompressionType max | Out-Null

    # ── 5. ISO amorcable ─────────────────────────────────────────────────────
    Step 'Construction de l''ISO'
    $boot = "2#p0,e,b$media\boot\etfsboot.com#pEF,e,b$media\efi\microsoft\boot\efisys.bin"
    & $oscdimg -m -o -u2 -udfver102 "-bootdata:$boot" -lWIN11_OPTI $media $Sortie
    if ($LASTEXITCODE -ne 0) { throw 'oscdimg a echoue.' }

    Write-Host ''
    Write-Host "  ISO prete : $Sortie" -ForegroundColor Green
    Write-Host "  Profil embarque : $moteurArgs" -ForegroundColor DarkGray
}
catch {
    Write-Host "Echec : $_" -ForegroundColor Red
    if (Get-WindowsImage -Mounted | Where-Object Path -eq $mount) { Dismount-WindowsImage -Path $mount -Discard | Out-Null }
    Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue | Out-Null
    throw
}
finally {
    Remove-Item "$Travail\install.wim", $mount -Recurse -Force -ErrorAction SilentlyContinue
}
