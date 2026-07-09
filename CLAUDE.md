# CLAUDE.md — AppsSwitch

Utilitaire macOS (menu bar, `LSUIElement`) qui cycle entre toutes les fenêtres individuelles ouvertes via ⌥Tab / ⌥⇧Tab, avec overlay de miniatures live — voir `MEMORY.md` pour l'état à jour et `TODOS.md` pour la liste des tâches.

Ce fichier suit les conventions de doc auto-maintenue définies dans `~/DevApps/CLAUDE.md` (ou `~/Documents/GitHub/CLAUDE.md`) et les règles build/release macOS spécifiques (signature, notarisation, profil `AppliMacVincentGithub`) qui y sont documentées.

## Spécificités de ce projet

- Cible `MACOSX_DEPLOYMENT_TARGET: 26.0` — ScreenCaptureKit et `CGEventTap` sont utilisés sans fallback vers des API plus anciennes (voir `ARCHITECTURE.md`).
- Pas de fenêtre principale : toute l'app tourne en accessory, pilotée par `AppDelegate` + `OverlayController`.
- `SWIFT_STRICT_CONCURRENCY: complete` — certains points d'intégration C (CGEventTap, kAX* constants) nécessitent `nonisolated(unsafe)` ou `@preconcurrency import`, documentés inline avec leur justification.
