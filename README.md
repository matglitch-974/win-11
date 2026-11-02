# win-11

Allège et optimise Windows 11 en une commande. Supprime le bloatware, coupe la télémétrie, nettoie l'interface, et pousse les performances au maximum.

---

## Utilisation

Ouvrir PowerShell et coller :

```powershell
irm https://is.gd/win11install|iex
```

Une fenêtre UAC s'ouvre — cliquer **Oui**. Le script se charge du reste en 6 étapes.

> Fonctionne sur Windows 11 (toutes versions). Requiert une connexion internet au premier lancement.

---

## Ce que le script fait

### [1/6] Bloatware supprimé
Cortana · Teams pré-installé · Bing News/Météo/Search · Xbox App + overlays · Mail & Calendrier · Skype · Phone Link · Clipchamp · Power Automate · Solitaire · Dev Home · Outlook (nouvelle version) · Mixed Reality Portal · Feedback Hub · Maps · Alarmes · Magnétophone · OneConnect · Sticky Notes · Todos

**Ne touche pas :** Calculatrice, Photos, Capture d'écran, Bloc-notes, Paint, Terminal, Store, Windows Security, .NET, VCLibs.

---

### [2/6] Télémétrie & Confidentialité
- Télémétrie → niveau 0 (GPO)
- Publicité personnalisée, Cortana, Bing, Copilot, historique d'activités → désactivés
- **24 tâches planifiées Microsoft** désactivées : télémétrie, diagnostics, WinSAT, mémoire, sécurité famille, Defender (scans planifiés seulement — la protection temps réel reste active)
- Delivery Optimization → local seulement (pas de P2P avec des inconnus)

### [3/7] Interface & Démarrage
- Widgets, Chat, suggestions, apps silencieuses → désactivés
- Extensions de fichiers et fichiers cachés → visibles
- Transparence → désactivée
- **Applications en arrière-plan → désactivées globalement**
- **OneDrive retiré du démarrage** (sans désinstaller)
- Maintenance automatique Windows → désactivée

### [4/7] Services désactivés (16)
`DiagTrack` · `dmwappushservice` · `PcaSvc` · `WerSvc` · `SysMain (Superfetch)` · `MapsBroker` · `lfsvc` · `RetailDemo` · `RemoteRegistry` · `TrkWks` · `AJRouter` · `Fax` · `XblAuthManager` · `XblGameSave` · `XboxNetApiSvc` · `xbgm`

### [5/7] Performance système
- **Plan d'alimentation** → Performances ultimes (fallback : Haute performance)
- Disque, veille, hibernation automatique → désactivés
- **Hibernation off** → libère de l'espace disque (= taille RAM)
- Effets visuels → Performance (animations, ombres, aperçus)
- **Arrêt rapide** : apps/services bloqués tués en 1-2 s au lieu de 5 s
- Délai démarrage applications boot → 0
- Priorité processeur → programmes au premier plan
- Kernel en RAM (`DisablePagingExecutive`)
- Page file encryption → désactivée
- NTFS LastAccess + noms 8.3 → désactivés (gain SSD/HDD)
- HAGS (Hardware-Accelerated GPU Scheduling) → activé
- Game Mode automatique → activé
- **Accélération souris → désactivée** (précision constante, essentiel pour le gaming)

### [6/7] Navigateurs & Thèmes
- **Internet Explorer** → fonctionnalité Windows désactivée
- **Edge** → désinstallé (via son propre setup + AppX legacy) ; réinstallation automatique bloquée par GPO
- **Firefox, Tor Browser, Brave** → installés via winget
- **Fonds d'écran 4K** (`C:\Windows\Web\4K\`) → supprimés (~200–300 MB)
- **Fonds d'écran thématiques** (Sunrise, Flow, Glow…) → supprimés ; le dossier `Windows` de base est conservé
- **Images d'écran de verrouillage** → supprimées

### [7/7] Réseau & Gaming
- Network throttling → désactivé
- Priorités GPU Priority 8 · CPU Priority 6 · Scheduling High pour les jeux
- **Nagle désactivé sur toutes les interfaces** réseau (latence TCP réduite)
- Cache DNS élargi (résolution plus rapide)

---

## Réversibilité

- **Applications** : se réinstallent depuis le Microsoft Store.
- **Plan d'alimentation** : `Paramètres → Système → Alimentation` → Équilibré.
- **Hibernation** : `powercfg -h on` dans une invite admin.
- **Services** : `services.msc` → relancer et remettre en Automatique.
- **Registre** : toutes les clés sont dans `HKCU` ou `HKLM\SOFTWARE\Policies` — point de restauration recommandé avant exécution.

Créer un point de restauration : `Win+R` → `SystemPropertiesProtection` → *Créer*.

---

## Inspiré de

- [Win11Debloat](https://github.com/Raphire/Win11Debloat) par **Raphire** (MIT)

---

## Licence

MIT
