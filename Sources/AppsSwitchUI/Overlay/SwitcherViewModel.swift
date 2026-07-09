import AppKit
import AppsSwitchCore
import Observation

@MainActor
@Observable
public final class SwitcherViewModel {
    public private(set) var windows: [WindowInfo] = []
    public private(set) var selectedIndex = 0
    public private(set) var thumbnails: [CGWindowID: NSImage] = [:]

    private let thumbnailCapture = WindowThumbnailCapture()
    private var thumbnailLoadTask: Task<Void, Never>?

    public init() {}

    public var selectedWindow: WindowInfo? {
        windows.indices.contains(selectedIndex) ? windows[selectedIndex] : nil
    }

    public func begin(excludingOwnerPID excludedPID: pid_t) {
        windows = WindowEnumerator.currentWindows(excludingOwnerPID: excludedPID)
        selectedIndex = WindowOrdering.initialSelectionIndex(windowCount: windows.count)
        loadThumbnails()
    }

    public func advance(forward: Bool) {
        guard !windows.isEmpty else { return }
        selectedIndex = WindowOrdering.advancedIndex(from: selectedIndex, count: windows.count, forward: forward)
    }

    public func reset() {
        thumbnailLoadTask?.cancel()
        thumbnailLoadTask = nil
        windows = []
        selectedIndex = 0
        thumbnails.removeAll()
        let capture = thumbnailCapture
        Task { await capture.invalidateCache() }
    }

    private func loadThumbnails() {
        thumbnailLoadTask?.cancel()
        let capture = thumbnailCapture
        let targets = windows
        thumbnailLoadTask = Task { [weak self] in
            for window in targets {
                guard !Task.isCancelled else { return }
                guard let cgImage = try? await capture.thumbnail(for: window.windowID) else { continue }
                guard !Task.isCancelled, let self else { return }
                self.thumbnails[window.windowID] = NSImage(cgImage: cgImage, size: .zero)
            }
        }
    }
}
