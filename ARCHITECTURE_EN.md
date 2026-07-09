# Architecture — AppsSwitch

Source of truth (English). `ARCHITECTURE.md` is the French mirror — keep both in sync in the same edit.

## Overview

AppsSwitch is a background macOS utility (`LSUIElement`, no Dock icon, no main window) that lets the user cycle through every individual on-screen window on the active Space — not just applications, unlike native `Cmd-Tab`. Triggered by holding **⌥ (Option)** and pressing **Tab** (or **⇧Tab** to go backward), it shows a floating overlay with a live thumbnail of each window; releasing Option activates the highlighted one.

## Module layout

Three XcodeGen targets, mirroring the sibling `MoveApps` project's structure:

- **AppsSwitchCore** (framework) — all business logic, no UI. Owns window enumeration, activation, thumbnail capture, permissions, and the raw keyboard event tap.
- **AppsSwitchUI** (framework) — the overlay panel, its SwiftUI content, and the permissions onboarding screen. Depends on AppsSwitchCore.
- **AppsSwitch** (executable) — `AppDelegate` + `AppsSwitchApp` (menu bar `MenuBarExtra`, no `Window` scene). Wires Core and UI together.

## Key components (AppsSwitchCore)

| Component | Responsibility |
|---|---|
| `WindowEnumerator` | Wraps `CGWindowListCopyWindowInfo` (`.optionOnScreenOnly`, `.excludeDesktopElements`). Filters to `layer == 0`, excludes AppsSwitch's own PID, excludes known system chrome (`WindowManager`/Stage Manager tiling handles), excludes windows with both an empty title and a negligible size. The returned order is already front-to-back and doubles as an MRU proxy — no separate bookkeeping needed. |
| `WindowOrdering` | Pure, unit-tested cycling logic: `initialSelectionIndex` (first Tab press lands on index 1, the previous window — matching the Cmd-Tab/Alt-Tab convention) and `advancedIndex` (wrapping increment/decrement). |
| `WindowActivator` | Activates a *specific* window, not just its owning app. There is no public bridge from a `CGWindowID` to its `AXUIElement`, so windows are matched by frame (position + size, small point tolerance) between `WindowEnumerator`'s result and the owning app's `kAXWindowsAttribute` list. Raises via `kAXRaiseAction`, then calls `NSRunningApplication.activate` — in that order, since `activate()` alone only brings the app's most-recently-used window forward. |
| `WindowThumbnailCapture` | Live per-window thumbnails via ScreenCaptureKit (`SCShareableContent` → `SCContentFilter(desktopIndependentWindow:)` → `SCScreenshotManager.captureImage`). `CGWindowListCreateImage` is obsolete since macOS 15, so this is the only capture path — no fallback. In-memory cache keyed by `CGWindowID`, invalidated when the overlay closes. |
| `EventTapManager` | Detects the ⌥Tab / ⌥⇧Tab gesture via a `CGEventTap` (`.cgSessionEventTap`, `.headInsertEventTap`) watching `keyDown`/`keyUp`/`flagsChanged`. Consumes (returns `nil` for) Tab presses while armed, which is what prevents the keystroke from reaching the frontmost app. Re-enables itself on `kCGEventTapDisabledByTimeout`/`...ByUserInput`. Reports state transitions (`armed`/`advance(forward:)`/`committed`/`cancelled`) on an `AsyncStream<SwitcherEvent>`. Deliberately a plain (non-actor-isolated) class: the tap callback is a `@convention(c)` function pointer invoked by the CFRunLoop and cannot itself be actor-isolated, so its mutable state is `nonisolated(unsafe)` with the invariant "only touched on the main run loop" enforced by construction. |
| `PermissionsManager` | Wraps `AXIsProcessTrusted`/`AXIsProcessTrustedWithOptions` (Accessibility) and `CGPreflightScreenCaptureAccess`/`CGRequestScreenCaptureAccess` (Screen Recording), plus deep-links into System Settings. `@Observable`, `@MainActor`. |

## Overlay (AppsSwitchUI)

- `OverlayPanel` — `NSPanel` subclass: `[.nonactivatingPanel, .borderless]`, `isFloatingPanel = true`, `level = .popUpMenu`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]`, `canBecomeKey` overridden to `false`. Never steals keyboard focus — the event tap drives all state.
- `OverlayController` (`@MainActor`) — owns the `EventTapManager` and `SwitcherViewModel`, consumes the event stream, shows/positions/hides the panel, and calls `WindowActivator` on commit. Suppresses the overlay entirely when there are 0 or 1 windows (nothing to switch to).
- `SwitcherViewModel` (`@Observable`) — snapshots the window list once per invocation (`begin`), tracks `selectedIndex` via `WindowOrdering`, and kicks off thumbnail loading as a cancellable background task.
- `SwitcherOverlayView` / `ThumbnailCellView` — SwiftUI rendering; falls back to the owning app's icon when a thumbnail hasn't loaded yet (or Screen Recording isn't granted), rather than an indefinite spinner.

## Coordinate systems note

`AXUIElement`'s `kAXPositionAttribute`/`kAXSizeAttribute` and `CGWindowListCopyWindowInfo`'s `kCGWindowBounds` both use the same top-left-origin, global-screen coordinate space — unlike `NSWindow.frame`, which is bottom-left-origin. `WindowActivator`'s frame matching relies on this and does no coordinate conversion.

## Known V1 scope limits (product decisions, not accidental gaps)

- Active Space only — no cross-Space or cross-display window list.
- Minimized windows excluded (`CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` doesn't return them).
- No persisted MRU order beyond what the window server's own z-order already provides.

## Concurrency

`SWIFT_STRICT_CONCURRENCY: complete` throughout. Two spots need explicit opt-outs, both documented inline at the point of use:
- `PermissionsManager`: `@preconcurrency import ApplicationServices` — the `kAX*` C constants aren't concurrency-annotated in the imported headers.
- `EventTapManager`: `nonisolated(unsafe)` on its mutable state, because the CGEventTap C callback cannot be actor-isolated.

## Release

`Scripts/release.sh` (adapted from the `MoveApps`/`Templates/Scripts/release-simple.sh` pattern): `xcodegen generate` → Release build (unsigned) → stage via `ditto` → sign nested frameworks then the app (Developer ID + Hardened Runtime, with retry for the timestamp server) → DMG → notarize via the shared `AppliMacVincentGithub` keychain profile → staple. No Sparkle (no auto-update feed in V1).
