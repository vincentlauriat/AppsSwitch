import CoreGraphics

/// Detects the ⌥Tab / ⌥⇧Tab gesture via a `CGEventTap` and reports transitions on `events`.
///
/// This is a plain (non-actor-isolated) class by necessity: the tap's callback is a
/// `@convention(c)` function pointer invoked directly by the CFRunLoop, so it cannot itself be
/// actor-isolated. The mutable state it touches is marked `nonisolated(unsafe)`; the invariant
/// "only ever touched on the main run loop" is enforced by construction — the tap's run loop
/// source is only ever added to `CFRunLoopGetMain()`, and `start()`/`stop()` are main-thread-only.
public final class EventTapManager {
    public let events: AsyncStream<SwitcherEvent>

    private nonisolated(unsafe) var continuation: AsyncStream<SwitcherEvent>.Continuation!
    private nonisolated(unsafe) var eventTap: CFMachPort?
    private nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
    private nonisolated(unsafe) var isArmed = false

    private static let tabKeyCode: Int64 = 48
    private static let escapeKeyCode: Int64 = 53

    public init() {
        var continuation: AsyncStream<SwitcherEvent>.Continuation!
        events = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    /// Requires Accessibility permission: tap creation itself doesn't fail without it, but no
    /// events are ever delivered, so callers should check `PermissionsManager` first. Must be
    /// called on the main thread.
    @discardableResult
    public func start() -> Bool {
        guard eventTap == nil else { return true }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<EventTapManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    public func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isArmed = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The tap gets disabled by the system if our callback is too slow to respond, or the
        // user disables it manually in some edge cases — re-enabling here is the documented fix
        // for "the shortcut silently stops working after a while".
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        switch type {
        case .flagsChanged:
            return handleFlagsChanged(event)
        case .keyDown:
            return handleKeyDown(event)
        default:
            return Unmanaged.passRetained(event)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let optionHeld = event.flags.contains(.maskAlternate)
        if optionHeld, !isArmed {
            isArmed = true
            continuation.yield(.armed)
        } else if !optionHeld, isArmed {
            isArmed = false
            continuation.yield(.committed)
        }
        return Unmanaged.passRetained(event)
    }

    private func handleKeyDown(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isArmed else { return Unmanaged.passRetained(event) }

        switch event.getIntegerValueField(.keyboardEventKeycode) {
        case Self.tabKeyCode:
            // Consumed: this is what prevents ⌥Tab from reaching the frontmost app (e.g.
            // inserting a tab character or moving focus) while the switcher is armed.
            continuation.yield(.advance(forward: !event.flags.contains(.maskShift)))
            return nil
        case Self.escapeKeyCode:
            isArmed = false
            continuation.yield(.cancelled)
            return nil
        default:
            return Unmanaged.passRetained(event)
        }
    }
}
