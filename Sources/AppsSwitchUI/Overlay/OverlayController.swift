import AppKit
import SwiftUI
import AppsSwitchCore

@MainActor
public final class OverlayController {
    private let eventTapManager: EventTapManager
    private let viewModel = SwitcherViewModel()
    private var panel: OverlayPanel?
    private var eventTask: Task<Void, Never>?

    private static let cellWidth: CGFloat = 180
    private static let cellSpacing: CGFloat = 16
    private static let panelPadding: CGFloat = 24
    private static let panelHeight: CGFloat = 180

    public init(eventTapManager: EventTapManager) {
        self.eventTapManager = eventTapManager
    }

    public func start() {
        guard eventTask == nil else { return }
        eventTapManager.start()
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in eventTapManager.events {
                handle(event)
            }
        }
    }

    public func stop() {
        eventTask?.cancel()
        eventTask = nil
        eventTapManager.stop()
        dismissPanel()
    }

    private func handle(_ event: SwitcherEvent) {
        switch event {
        case .armed:
            present()
        case .advance(let forward):
            viewModel.advance(forward: forward)
        case .committed:
            commitSelection()
        case .cancelled:
            dismissPanel()
        }
    }

    private func present() {
        viewModel.begin(excludingOwnerPID: ProcessInfo.processInfo.processIdentifier)
        // Nothing to switch to with 0 or 1 window — showing the overlay just to highlight the
        // window the user is already on would be noise, not a switcher.
        guard viewModel.windows.count > 1 else { return }

        let panel = self.panel ?? OverlayPanel(contentRect: .zero)
        panel.contentViewController = NSHostingController(rootView: SwitcherOverlayView(viewModel: viewModel))
        panel.setContentSize(contentSize(forWindowCount: viewModel.windows.count))
        centerOnMainScreen(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func commitSelection() {
        if let window = viewModel.selectedWindow {
            WindowActivator.activate(window)
        }
        dismissPanel()
    }

    private func dismissPanel() {
        panel?.orderOut(nil)
        viewModel.reset()
    }

    private func contentSize(forWindowCount count: Int) -> NSSize {
        let width = CGFloat(count) * Self.cellWidth
            + CGFloat(max(count - 1, 0)) * Self.cellSpacing
            + Self.panelPadding * 2
        return NSSize(width: width, height: Self.panelHeight)
    }

    private func centerOnMainScreen(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelFrame = panel.frame
        let origin = NSPoint(
            x: screenFrame.midX - panelFrame.width / 2,
            y: screenFrame.midY - panelFrame.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
