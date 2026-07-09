import AppKit
@preconcurrency import ApplicationServices

public enum WindowActivator {
    /// There's no public bridge from a `CGWindowID` to its `AXUIElement` (the private
    /// `_AXUIElementGetWindow` exists but is intentionally not used here for stability across
    /// macOS versions), so windows are matched by frame instead — `AXUIElement`'s position/size
    /// attributes and `CGWindowListCopyWindowInfo`'s bounds share the same top-left-origin,
    /// global-screen coordinate space, so no conversion is needed, just a small point tolerance
    /// to absorb float rounding differences between the two APIs.
    private static let frameMatchTolerance: CGFloat = 2

    /// Raises and activates the exact window described by `window`, not just its owning app —
    /// `NSRunningApplication.activate` alone only brings the app's most-recently-used window
    /// forward, which is wrong when the user picked a different one from the switcher.
    @discardableResult
    public static func activate(_ window: WindowInfo) -> Bool {
        let didRaise: Bool
        if let axWindow = matchingAXWindow(for: window) {
            AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
            didRaise = true
        } else {
            didRaise = false
        }

        NSRunningApplication(processIdentifier: window.ownerPID)?.activate(options: .activateIgnoringOtherApps)
        return didRaise
    }

    private static func matchingAXWindow(for window: WindowInfo) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(window.ownerPID)

        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let axWindows = windowsRef as? [AXUIElement] else {
            return nil
        }

        return axWindows.first { axWindow in
            guard let frame = frame(of: axWindow) else { return false }
            return frame.origin.x.isApproximatelyEqual(window.frame.origin.x, tolerance: frameMatchTolerance)
                && frame.origin.y.isApproximatelyEqual(window.frame.origin.y, tolerance: frameMatchTolerance)
                && frame.width.isApproximatelyEqual(window.frame.width, tolerance: frameMatchTolerance)
                && frame.height.isApproximatelyEqual(window.frame.height, tolerance: frameMatchTolerance)
        }
    }

    private static func frame(of axWindow: AXUIElement) -> CGRect? {
        guard let position = point(axWindow, kAXPositionAttribute),
              let size = size(axWindow, kAXSizeAttribute) else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let axValue = copyAXValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let axValue = copyAXValue(element, attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    private static func copyAXValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success,
              let value = valueRef, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }
        return (value as! AXValue)
    }
}

private extension CGFloat {
    func isApproximatelyEqual(_ other: CGFloat, tolerance: CGFloat) -> Bool {
        abs(self - other) <= tolerance
    }
}
