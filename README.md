# win-11

Allège Windows 11 en une commande. Supprime le bloatware, coupe la télémétrie, nettoie la barre des tâches.

---

## Utilisation

Ouvrir PowerShell et coller :

```powershell
irm https://is.gd/win11install|iex
```

Une fenêtre UAC s'ouvre — cliquer **Oui**. Le script se charge du reste.

> Fonctionne sur Windows 11 (toutes versions). Requiert une connexion internet au premier lancement.

---

## Ce que le script fait

### Applications supprimées
| Application | Pourquoi |
|---|---|
| Cortana | Assistante vocale inutilisée |
| Microsoft Teams (pré-installé) | Remplacé par Teams téléchargé depuis le Store si besoin |
| Bing News / Météo | Publicité déguisée |
| Xbox App + overlays | Sauf si tu joues sur Xbox Game Pass |
| Mail & Calendrier | Remplacé par Outlook Web ou client tiers |
| Skype | Obsolète |
| Phone Link | Inutile si pas de smartphone Samsung/Android lié |
| Clipchamp | Éditeur vidéo promotionnel |
| Power Automate Desktop | Usage très ciblé |
| Solitaire Collection | Jeu avec pubs |
| Bing Search dans le menu Démarrer | Remplacé par la recherche locale |
| Dev Home | Pour les devs inscrits au programme |
| Outlook (nouvelle version) | Si non souhaité |
| Mixed Reality Portal | Sauf casque WMR |
| Feedback Hub | Rapports automatiques Microsoft |
| Maps | Rarement utilisé en dehors d'un PC tactile |
| Alarmes | Rarement utilisé sur PC |
| Magnétophone | Remplacé par Audacity ou app dédiée |
| OneConnect | Mobile Plans (inutile) |
| Sticky Notes | Remplacé par Obsidian, Notion, etc. |
| Todos | Remplacé par app dédiée |

**Ne touche pas** : Calculatrice, Photos, Capture d'écran, Bloc-notes, Paint, Terminal, Store, Windows Security, .NET, VCLibs.

---

### Confidentialité & Télémétrie
- Télémétrie Windows → niveau 0 (désactivée par GPO)
- Publicité personnalisée → désactivée
- Suivi des applications lancées → désactivé
- Cortana et Bing dans le menu Démarrer → désactivés
- Copilot → désactivé
- Historique d'activités → désactivé
- Rapports d'erreurs Windows → désactivés
- Notifications de feedback → désactivées
- Services `DiagTrack`, `dmwappushservice`, `PcaSvc` → désactivés

### Interface
- Widgets (barre des tâches) → masqués
- Chat / Teams intégré → masqué
- Barre de recherche → icône uniquement
- Extensions de fichiers → visibles
- Fichiers et dossiers cachés → visibles
- Suggestions dans le menu Démarrer → désactivées
- Conseils et astuces au démarrage → désactivés
- Applications silencieuses pré-installées → bloquées

---

## Réversibilité

- **Applications** : chaque app supprimée se réinstalle depuis le Microsoft Store (chercher le nom).
- **Registre** : les clés ajoutées sont toutes dans `HKCU` (profil utilisateur) ou `HKLM\SOFTWARE\Policies` — réversibles manuellement ou via un point de restauration.
- **Services** : `services.msc` → chercher le service → relancer et re-paramétrer sur "Automatique".

Pour une réversibilité complète, créer un point de restauration avant de lancer le script : `Win+R` → `SystemPropertiesProtection` → *Créer*.

---

## Inspiré de

- [Win11Debloat](https://github.com/Raphire/Win11Debloat) par **Raphire** (MIT) — référence open-source du débloat Windows 11.

---

## Licence

MIT — Faire ce qu'on veut.
