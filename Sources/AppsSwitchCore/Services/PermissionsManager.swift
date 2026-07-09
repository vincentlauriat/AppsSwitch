import AppKit
@preconcurrency import ApplicationServices
import CoreGraphics
import Observation

public enum SystemSettingsPane {
    case accessibility
    case screenRecording

    var url: URL {
        switch self {
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        case .screenRecording:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        }
    }
}

@Observable
@MainActor
public final class PermissionsManager {
    public private(set) var status: PermissionStatus

    public init() {
        status = Self.currentStatus()
    }

    public func refresh() {
        status = Self.currentStatus()
    }

    /// macOS only shows the Accessibility prompt once per app; after a denial the user must flip
    /// the toggle in System Settings themselves, so `openSystemSettings` is the fallback path.
    public func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Unlike Accessibility, granting Screen Recording from the prompt does not take effect until
    /// the app is relaunched — the caller is responsible for telling the user to quit and reopen.
    public func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    public func openSystemSettings(_ pane: SystemSettingsPane) {
        NSWorkspace.shared.open(pane.url)
    }

    private static func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }
}
