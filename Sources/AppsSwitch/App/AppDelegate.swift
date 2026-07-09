import AppKit
import SwiftUI
import AppsSwitchCore
import AppsSwitchUI

/// AppsSwitch has no main window: it's a pure background utility surfaced only through its
/// menu-bar item, so the Dock policy is fixed to `.accessory` for the whole app lifetime
/// (unlike MoveApps, there's no user-facing toggle for this). The one on-demand window is the
/// permissions onboarding sheet, created imperatively here rather than as a SwiftUI `Window`
/// scene so it never reopens on its own (no Dock icon to click, no Cmd-N).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let permissionsManager = PermissionsManager()
    private var onboardingWindow: NSWindow?
    private let eventTapManager = EventTapManager()
    private lazy var overlayController = OverlayController(eventTapManager: eventTapManager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        permissionsManager.refresh()
        presentOnboardingIfNeeded()
        startSwitcherIfPermitted()
    }

    /// Screen Recording grants only take effect after a relaunch, but Accessibility grants are
    /// picked up live — re-checking here catches the user flipping either toggle in System
    /// Settings and coming back without having to relaunch manually.
    func applicationDidBecomeActive(_ notification: Notification) {
        permissionsManager.refresh()
        presentOnboardingIfNeeded()
        startSwitcherIfPermitted()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        overlayController.stop()
    }

    /// The event tap requires Accessibility; Screen Recording only affects thumbnail quality
    /// (see `ThumbnailCellView`'s app-icon placeholder), so it isn't a precondition to start.
    private func startSwitcherIfPermitted() {
        guard permissionsManager.status.accessibilityGranted else { return }
        overlayController.start()
    }

    func showPermissionsOnboarding() {
        presentOnboardingIfNeeded(force: true)
    }

    private func presentOnboardingIfNeeded(force: Bool = false) {
        if !force && permissionsManager.status.allGranted {
            onboardingWindow?.close()
            return
        }
        if let window = onboardingWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let controller = NSHostingController(rootView: PermissionsOnboardingView(permissionsManager: permissionsManager))
        let window = NSWindow(contentViewController: controller)
        window.title = "AppsSwitch — Autorisations requises"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()

        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.onboardingWindow = nil
        }

        onboardingWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
