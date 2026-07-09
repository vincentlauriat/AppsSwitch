import AppKit

/// A borderless, non-activating floating panel: the event tap drives selection state directly,
/// so the panel never needs (and must never take) key focus — stealing focus would interrupt
/// whatever the user was typing into when they invoked the switcher.
public final class OverlayPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
    }

    override public var canBecomeKey: Bool { false }
}
