# AppsSwitch

App macOS native (menu bar, `LSUIElement`) qui cycle entre **toutes les fenêtres individuelles** ouvertes sur le Space actif — pas seulement entre applications comme `Cmd-Tab` natif. Si Terminal a 4 fenêtres ouvertes et une autre app en a 2, `Cmd-Tab` ne propose que 2 « slots » ; AppsSwitch en propose 6, façon `Alt-Tab` Windows.

## Fonctionnement

Maintenir **⌥ (Option)** et appuyer sur **Tab** fait apparaître un overlay avec une miniature live de chaque fenêtre ouverte. Continuer à appuyer sur Tab avance dans la liste, **⇧Tab** recule. Relâcher Option active la fenêtre sélectionnée. **Échap** annule sans rien activer.

## Features

| Feature | État |
|---|---|
| Cycle entre toutes les fenêtres (⌥Tab / ⌥⇧Tab) | ✅ |
| Overlay avec miniatures live (ScreenCaptureKit) | ✅ |
| Activation de la fenêtre exacte sélectionnée (pas juste l'app) | ✅ |
| Onboarding permissions (Accessibility + Screen Recording) | ✅ |
| Menu bar (vérifier permissions, quitter) | ✅ |
| Icône d'app custom | ✅ |
| Fenêtres minimisées | ⬜ (hors scope V1) |
| Multi-Spaces / multi-écrans | ⬜ (hors scope V1, Space actif uniquement) |

## Install

DMG signé + notarisé : `release/AppsSwitch-0.1.0.dmg`. Distribution manuelle pour l'instant (pas de feed Sparkle/auto-update).

Pour rebuilder depuis les sources :

```bash
xcodegen generate
xcodebuild -scheme AppsSwitch -configuration Release build
# ou, pour un DMG signé + notarisé :
./Scripts/release.sh 0.1.0
```

L'app nécessite les permissions **Accessibité** et **Enregistrement d'écran** (demandées au premier lancement, avec deep-links vers Réglages Système).

## Project layout

```
AppsSwitch/
├── project.yml                 # spec XcodeGen
├── Scripts/release.sh          # build + sign + notarize + DMG
├── Sources/
│   ├── AppsSwitchCore/         # logique métier (pas d'UI)
│   │   ├── Models/             # WindowInfo, SwitcherEvent, PermissionStatus
│   │   ├── Services/           # WindowEnumerator, WindowActivator, WindowThumbnailCapture, PermissionsManager
│   │   └── Support/            # EventTapManager, WindowOrdering
│   ├── AppsSwitchUI/            # overlay + onboarding SwiftUI
│   │   ├── Overlay/
│   │   ├── MenuBar/
│   │   └── Onboarding/
│   └── AppsSwitch/              # exécutable (App/AppDelegate, Resources)
└── Tests/AppsSwitchCoreTests/   # tests unitaires (logique pure uniquement)
```

## Roadmap

Voir `PLAN.md` pour le détail des phases et `TODOS.md` pour ce qui reste (icône, première release, extension éventuelle du scope).

Voir aussi `MEMORY.md`, `CHANGES.md`, `ARCHITECTURE.md` (`ARCHITECTURE_EN.md` en anglais, source de vérité).

## License

MIT © 2026 Vincent Lauriat — see [LICENSE](LICENSE).
