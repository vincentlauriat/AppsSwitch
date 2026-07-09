import CoreGraphics
import Foundation

public enum WindowEnumerator {
    /// Below this size (in points) a window is treated as a floating toolbar/palette rather than
    /// a switchable window — e.g. some apps' tool palettes report an empty title and a tiny frame
    /// but still show up in `CGWindowListCopyWindowInfo`. Only applied when the title is also
    /// empty, so legitimately untitled single-window utilities aren't excluded.
    private static let minimumSwitchableDimension: CGFloat = 40

    /// Apple system processes whose on-screen "windows" are UI chrome, not switchable app
    /// windows — e.g. `WindowManager` (Stage Manager / tiling) draws a titled "Tiling Handle
    /// Window" that survives the empty-title heuristic below since it does have a title.
    /// Confirmed by dumping real desktop state during Phase 2 manual verification.
    private static let excludedOwnerNames: Set<String> = ["WindowManager"]

    /// Windows on the active Space, front-to-back — `CGWindowListCopyWindowInfo` with
    /// `.optionOnScreenOnly` already returns entries in that z-order, so this list doubles as an
    /// MRU proxy without any extra bookkeeping.
    public static func currentWindows(excludingOwnerPID excludedPID: pid_t) -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]] else {
            return []
        }

        return rawList.compactMap { entry in
            windowInfo(from: entry, excludingOwnerPID: excludedPID)
        }
    }

    private static func windowInfo(from entry: [String: AnyObject], excludingOwnerPID excludedPID: pid_t) -> WindowInfo? {
        guard let layer = entry[kCGWindowLayer as String] as? Int, layer == 0 else { return nil }
        guard let windowID = entry[kCGWindowNumber as String] as? CGWindowID else { return nil }
        guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t, ownerPID != excludedPID else { return nil }
        guard let ownerName = entry[kCGWindowOwnerName as String] as? String,
              !excludedOwnerNames.contains(ownerName) else { return nil }
        guard let boundsEntry = entry[kCGWindowBounds as String] as? [String: Any],
              let frame = CGRect(dictionaryRepresentation: boundsEntry as CFDictionary) else { return nil }

        let title = entry[kCGWindowName as String] as? String ?? ""
        let isNegligible = title.isEmpty
            && (frame.width < minimumSwitchableDimension || frame.height < minimumSwitchableDimension)
        guard !isNegligible else { return nil }

        return WindowInfo(
            windowID: windowID,
            ownerPID: ownerPID,
            ownerName: ownerName,
            title: title,
            frame: frame,
            layer: layer
        )
    }
}
