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
| Application | Note |
|---|---|
| Cortana standalone | Remplacé par la recherche Windows |
| Microsoft Teams (pré-installé) | Télécharger depuis le Store si besoin |
| Bing News / Bing Météo / Bing Search | Publicité déguisée |
| Xbox App + overlays + services | Sauf si Xbox Game Pass |
| Mail & Calendrier | Préférer Outlook Web ou client tiers |
| Skype | Obsolète |
| Phone Link | Inutile sans smartphone lié |
| Clipchamp | Éditeur vidéo promotionnel |
| Power Automate Desktop | Usage très ciblé |
| Solitaire Collection | Jeu avec publicités |
| Dev Home | Programme développeurs |
| Outlook (nouvelle version) | |
| Mixed Reality Portal | Sauf casque WMR |
| Feedback Hub | Rapports automatiques |
| Maps / Alarmes / Magnétophone | Rarement utiles sur PC |
| OneConnect / Sticky Notes / Todos | Remplacés par apps dédiées |

**Ne touche pas :** Calculatrice, Photos, Capture d'écran, Bloc-notes, Paint, Terminal, Store, Windows Security, .NET, VCLibs.

---

### [2/6] Télémétrie & Confidentialité
- Télémétrie → niveau 0 (GPO)
- Publicité personnalisée → désactivée
- Cortana + Bing dans le menu Démarrer → désactivés
- Copilot → désactivé
- Historique d'activités → désactivé
- Rapports d'erreurs Windows → désactivés
- 12 tâches planifiées de télémétrie Microsoft → désactivées

### [3/6] Interface & Barre des tâches
- Widgets et Chat intégré → masqués
- Recherche → icône uniquement
- Extensions de fichiers → visibles
- Fichiers cachés → visibles
- Transparence → désactivée
- Toutes les suggestions et apps silencieuses → bloquées

### [4/6] Services désactivés
`DiagTrack` · `dmwappushservice` · `PcaSvc` · `WerSvc` · `MapsBroker` · `lfsvc` · `RetailDemo` · `RemoteRegistry` · `TrkWks` · `AJRouter` · `XblAuthManager` · `XblGameSave` · `XboxNetApiSvc` · `xbgm`

### [5/6] Performance système
- **Plan d'alimentation** → Performances ultimes (fallback : Haute performance)
- **Effets visuels** → Performance (animations désactivées, ombres, transparences)
- **Priorité processeur** → Programmes au premier plan
- **Kernel en RAM** — `DisablePagingExecutive` activé
- **NTFS** — LastAccess et noms 8.3 désactivés (gain lecture/écriture SSD/HDD)
- **HAGS** (Hardware-Accelerated GPU Scheduling) → activé
- **Game Mode** automatique → activé

### [6/6] Réseau & Gaming
- **Network throttling** → désactivé
- **Priorités GPU/CPU jeux** → Maximum (GPU Priority 8, CPU Priority 6, Scheduling High)
- **Algorithme de Nagle** → désactivé sur toutes les interfaces (latence TCP réduite)
- **Cache DNS** → élargi (résolution DNS plus rapide)

---

## Réversibilité

- **Applications** : se réinstallent depuis le Microsoft Store.
- **Registre** : toutes les clés sont dans `HKCU` ou `HKLM\SOFTWARE\Policies` — réversibles manuellement ou via un point de restauration.
- **Plan d'alimentation** : `Paramètres → Système → Alimentation` pour revenir à Équilibré.
- **Services** : `services.msc` → relancer et remettre en Automatique.

Pour une réversibilité complète, créer un point de restauration avant d'exécuter :
`Win+R` → `SystemPropertiesProtection` → *Créer*.

---

## Inspiré de

- [Win11Debloat](https://github.com/Raphire/Win11Debloat) par **Raphire** (MIT)

---

## Licence

MIT
