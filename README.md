# win-11

Windows 11 optimisé pour la performance. Un seul moteur, deux usages :

- **Convertir un Windows existant**, réversible à 100 % grâce au journal (`-Restore`).
- **Générer une ISO** à partir de l'ISO officielle Microsoft, qui applique le même moteur à l'installation.

---

## Convertir ce PC

PowerShell, puis :

```powershell
irm https://is.gd/win11install | iex
```

Ou en local :

```powershell
.\win11.ps1                              # menu
.\win11.ps1 -Profil Complet
.\win11.ps1 -Profil Systeme -Extreme
.\win11.ps1 -Restore                     # annule la dernière exécution
```

## Générer l'ISO

```powershell
winget install Microsoft.WindowsADK       # fournit oscdimg (une fois)
.\build-iso.ps1 -Iso D:\Win11_x64.iso -Profil Complet
```

L'ISO produite installe Windows sans TPM, sans Secure Boot et sans compte Microsoft obligatoire. Les applications inutiles sont retirées de l'image avant même l'installation. Au premier démarrage de session, `win11.ps1` s'exécute avec le profil choisi. Le choix du disque reste manuel, par sécurité.

---

## Profils

| | Système | Complet | Complet OLED |
|---|:-:|:-:|:-:|
| Alimentation, CPU, timer, GPU, MSI, services | oui | oui | oui |
| Defender allégé (protection conservée) | oui | oui | oui |
| Retrait des applications, Copilot, Recall | | oui | oui |
| Télémétrie et confidentialité | | oui | oui |
| Confort : Snap, fin de tâche, volume par appli | | oui | oui |
| Thème noir pur, barre masquée, écran de veille | | | oui |

Options cumulables :

- `-Extreme` : coupe VBS/HVCI, les mitigations Spectre/Meltdown, l'hyperviseur et Defender.
- `-Navigateurs` : installe Firefox, Brave et Tor ; Edge n'est retiré que si Firefox s'est bien installé.

## Optimisations à gain mesurable

| Réglage | Effet |
|---|---|
| Plan Performances ultimes, core parking off, état CPU min 100 % | Fin de la latence de réveil des cœurs |
| Power Throttling off | Les processus en arrière-plan (compilation, encodage) ne sont plus bridés |
| `GlobalTimerResolutionRequests` | Restaure la résolution de timer globale (régularité des images par seconde) |
| `Win32PrioritySeparation` 0x26 | Quantums courts, premier plan favorisé |
| Mode MSI : GPU, réseau, NVMe, USB | Moins de latence d'interruption (DPC) |
| MPO off | Supprime les saccades et écrans noirs liés aux overlays |
| HAGS on, Game DVR off, Game Mode | Moins de charge CPU côté pilote graphique |
| USB selective suspend et PCIe ASPM off | Plus de micro-coupures des périphériques |
| SysMain off, LastAccess off, TRIM hebdomadaire | Moins d'écritures disque |
| Compression mémoire off (16 Go et plus) | Moins de cycles CPU gaspillés |
| Defender : CPU plafonné à 15 %, exclusions dev/jeux | Compilation et chargements nettement plus rapides |
| **Extrême** : VBS/HVCI off | De 5 à 15 % en jeu selon le CPU |
| **Extrême** : mitigations off | Gain surtout sur les CPU anciens et les I/O |

## Antivirus

Aucun antivirus open source n'égale Defender en protection temps réel sous Windows. ClamAV (GPLv2), le plus sérieux, analyse uniquement à la demande, avec une détection inférieure. Le profil par défaut garde donc Defender, mais allégé. `-Extreme` le coupe et installe ClamAV pour des analyses manuelles. Avant `-Extreme`, désactivez « Protection contre les falsifications » dans Sécurité Windows, faute de quoi Windows bloque la désactivation.

## Volume par application au survol

Le profil Complet installe EarTrumpet (MIT, mixeur par application) et Windhawk. Pour régler le volume d'une application en faisant défiler la molette sur son icône, ouvrez Windhawk puis installez le mod **Taskbar Volume Control Per-App**. Windhawk ne permet pas d'automatiser cette installation.

## Réversibilité

Chaque valeur est sauvegardée avant modification dans `C:\ProgramData\win-11\journal-*.json`. Sont restaurés : le registre, les services, les tâches planifiées, le plan d'alimentation et les réglages de démarrage. Un point de restauration système est aussi créé. Seules les applications supprimées restent à réinstaller depuis le Store.

## Limites connues

- ISO : les réglages utilisateur s'appliquent au premier compte connecté. Pour un compte ajouté plus tard, relancez `win11.ps1`.
- `-Extreme` rend inutilisables WSL2, Hyper-V, Docker Desktop et le Sandbox Windows.

---

Inspiré de [Win11Debloat](https://github.com/Raphire/Win11Debloat) (Raphire, MIT). Licence MIT.
