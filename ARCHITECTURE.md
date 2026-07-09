# Architecture — AppsSwitch

Miroir français. La version anglaise (`ARCHITECTURE_EN.md`) fait foi — les deux sont éditées ensemble à chaque changement.

## Vue d'ensemble

AppsSwitch est un utilitaire macOS en arrière-plan (`LSUIElement`, pas d'icône Dock, pas de fenêtre principale) qui permet de cycler entre toutes les fenêtres individuelles à l'écran sur le Space actif — pas seulement entre applications, contrairement à `Cmd-Tab` natif. Déclenché en maintenant **⌥ (Option)** et en appuyant sur **Tab** (ou **⇧Tab** pour reculer), il affiche un overlay flottant avec une miniature live de chaque fenêtre ; relâcher Option active celle sélectionnée.

## Découpage des modules

Trois targets XcodeGen, calqués sur la structure du projet frère `MoveApps` :

- **AppsSwitchCore** (framework) — toute la logique métier, aucune UI. Porte l'énumération des fenêtres, l'activation, la capture de miniatures, les permissions et l'event tap clavier brut.
- **AppsSwitchUI** (framework) — le panneau overlay, son contenu SwiftUI, et l'écran d'onboarding des permissions. Dépend d'AppsSwitchCore.
- **AppsSwitch** (exécutable) — `AppDelegate` + `AppsSwitchApp` (menu bar `MenuBarExtra`, pas de scène `Window`). Assemble Core et UI.

## Composants clés (AppsSwitchCore)

| Composant | Responsabilité |
|---|---|
| `WindowEnumerator` | Encapsule `CGWindowListCopyWindowInfo` (`.optionOnScreenOnly`, `.excludeDesktopElements`). Filtre `layer == 0`, exclut le PID d'AppsSwitch lui-même, exclut le bruit système connu (`WindowManager`/poignées de tuilage Stage Manager), exclut les fenêtres à la fois sans titre et de taille négligeable. L'ordre retourné est déjà front-to-back et sert de proxy MRU — aucune gestion séparée nécessaire. |
| `WindowOrdering` | Logique de cycle pure et testée unitairement : `initialSelectionIndex` (le premier Tab sélectionne l'index 1, la fenêtre précédente — convention Cmd-Tab/Alt-Tab) et `advancedIndex` (incrément/décrément avec boucle). |
| `WindowActivator` | Active une fenêtre *précise*, pas juste son application. Il n'existe pas de pont public entre un `CGWindowID` et son `AXUIElement` : le matching se fait par frame (position + taille, faible tolérance) entre le résultat de `WindowEnumerator` et la liste `kAXWindowsAttribute` de l'app propriétaire. Remonte via `kAXRaiseAction`, puis appelle `NSRunningApplication.activate` — dans cet ordre, car `activate()` seul ne remonte que la fenêtre la plus récente de l'app. |
| `WindowThumbnailCapture` | Miniatures live par fenêtre via ScreenCaptureKit (`SCShareableContent` → `SCContentFilter(desktopIndependentWindow:)` → `SCScreenshotManager.captureImage`). `CGWindowListCreateImage` est obsolète depuis macOS 15, donc c'est l'unique chemin de capture — pas de repli. Cache mémoire indexé par `CGWindowID`, invalidé à la fermeture de l'overlay. |
| `EventTapManager` | Détecte le geste ⌥Tab / ⌥⇧Tab via un `CGEventTap` (`.cgSessionEventTap`, `.headInsertEventTap`) surveillant `keyDown`/`keyUp`/`flagsChanged`. Consomme (retourne `nil` pour) les appuis sur Tab pendant que le switcher est armé, ce qui empêche la frappe d'atteindre l'app au premier plan. Se réactive automatiquement sur `kCGEventTapDisabledByTimeout`/`...ByUserInput`. Rapporte les transitions d'état (`armed`/`advance(forward:)`/`committed`/`cancelled`) sur un `AsyncStream<SwitcherEvent>`. Classe volontairement non isolée par acteur : le callback du tap est un pointeur de fonction `@convention(c)` invoqué par le CFRunLoop et ne peut pas lui-même être isolé par acteur — son état mutable est donc `nonisolated(unsafe)`, avec l'invariant « touché uniquement sur le run loop principal » garanti par construction. |
| `PermissionsManager` | Encapsule `AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions` (Accessibilité) et `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess` (Enregistrement d'écran), plus les deep-links vers Réglages Système. `@Observable`, `@MainActor`. |

## Overlay (AppsSwitchUI)

- `OverlayPanel` — sous-classe `NSPanel` : `[.nonactivatingPanel, .borderless]`, `isFloatingPanel = true`, `level = .popUpMenu`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `canBecomeKey` surchargé à `false`. Ne vole jamais le focus clavier — l'event tap pilote tout l'état.
- `OverlayController` (`@MainActor`) — possède l'`EventTapManager` et le `SwitcherViewModel`, consomme le flux d'événements, affiche/positionne/masque le panneau, et appelle `WindowActivator` au commit. Supprime l'overlay entièrement s'il y a 0 ou 1 fenêtre (rien à switcher).
- `SwitcherViewModel` (`@Observable`) — capture la liste des fenêtres une fois par invocation (`begin`), suit `selectedIndex` via `WindowOrdering`, et lance le chargement des miniatures en tâche annulable en arrière-plan.
- `SwitcherOverlayView` / `ThumbnailCellView` — rendu SwiftUI ; retombe sur l'icône de l'app propriétaire quand une miniature n'a pas encore chargé (ou que Screen Recording n'est pas accordé), plutôt qu'un spinner indéfini.

## Note sur les systèmes de coordonnées

Les attributs `kAXPositionAttribute`/`kAXSizeAttribute` d'`AXUIElement` et `kCGWindowBounds` de `CGWindowListCopyWindowInfo` utilisent tous deux le même espace de coordonnées à origine haut-gauche, écran global — contrairement à `NSWindow.frame`, à origine bas-gauche. Le matching de frame de `WindowActivator` s'appuie là-dessus sans conversion.

## Limites de scope V1 connues (décisions produit, pas des lacunes accidentelles)

- Space actif uniquement — pas de liste de fenêtres cross-Space ou cross-écran.
- Fenêtres minimisées exclues (`CGWindowListCopyWindowInfo` avec `.optionOnScreenOnly` ne les retourne pas).
- Pas d'ordre MRU persisté au-delà de ce que le z-order du window server fournit déjà.

## Concurrence

`SWIFT_STRICT_CONCURRENCY: complete` partout. Deux points nécessitent des dérogations explicites, documentées en ligne à leur point d'usage :
- `PermissionsManager` : `@preconcurrency import ApplicationServices` — les constantes C `kAX*` ne sont pas annotées pour la concurrence dans les headers importés.
- `EventTapManager` : `nonisolated(unsafe)` sur son état mutable, car le callback C du CGEventTap ne peut pas être isolé par acteur.

## Release

`Scripts/release.sh` (adapté du pattern `MoveApps`/`Templates/Scripts/release-simple.sh`) : `xcodegen generate` → build Release (non signé) → staging via `ditto` → signature des frameworks imbriqués puis de l'app (Developer ID + Hardened Runtime, avec retry pour le serveur de timestamp) → DMG → notarisation via le profil trousseau partagé `AppliMacVincentGithub` → stapling. Pas de Sparkle (pas de flux d'auto-update en V1).
