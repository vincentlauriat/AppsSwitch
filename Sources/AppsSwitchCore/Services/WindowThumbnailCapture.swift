import AppKit
import ScreenCaptureKit

/// Captures a live thumbnail of a single window via ScreenCaptureKit.
///
/// `CGWindowListCreateImage` (the older, simpler API) is obsolete since macOS 15 — Apple's own
/// header marks it `SCREEN_CAPTURE_OBSOLETE(10.5, 14.0, 15.0)` and points to ScreenCaptureKit, so
/// there's no fallback path to fall back to on a macOS 26 deployment target.
public actor WindowThumbnailCapture {
    public enum CaptureError: Error, Sendable {
        case windowNotFound
    }

    /// Keyed by `windowID`, invalidated when the overlay closes (see `invalidateCache`) —
    /// thumbnails only need to reflect window contents at the moment the switcher was invoked,
    /// not stay live for the process lifetime.
    private var cache: [CGWindowID: CGImage] = [:]

    public init() {}

    public func thumbnail(for windowID: CGWindowID) async throws -> CGImage {
        if let cached = cache[windowID] {
            return cached
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let scWindow = content.windows.first(where: { $0.windowID == windowID }) else {
            throw CaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let scale = await MainActor.run { NSScreen.main?.backingScaleFactor ?? 2 }
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int(scWindow.frame.width * scale), 1)
        configuration.height = max(Int(scWindow.frame.height * scale), 1)
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        cache[windowID] = image
        return image
    }

    public func invalidateCache() {
        cache.removeAll()
    }
}
