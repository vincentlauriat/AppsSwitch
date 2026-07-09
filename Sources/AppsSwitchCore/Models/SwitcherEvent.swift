/// Raw gesture transitions detected by `EventTapManager`. Deliberately doesn't carry a window
/// index — the event tap only knows about key state, not the window list, so index bookkeeping
/// (via `WindowOrdering`) belongs to whatever consumes this stream (the overlay controller).
public enum SwitcherEvent: Equatable, Sendable {
    case armed
    case advance(forward: Bool)
    case committed
    case cancelled
}
