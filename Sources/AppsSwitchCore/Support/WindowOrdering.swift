/// Pure cycling logic, kept separate from `WindowEnumerator` so it's unit-testable without
/// touching the window server. The window list itself is assumed to already be in front-to-back
/// (MRU-proxy) order, as returned by `WindowEnumerator.currentWindows`.
public enum WindowOrdering {
    /// The index selected by the first Tab press: the previous window (index 1), not the one
    /// already on screen (index 0) — matches the Cmd-Tab/Alt-Tab convention.
    public static func initialSelectionIndex(windowCount: Int) -> Int {
        windowCount > 1 ? 1 : 0
    }

    public static func advancedIndex(from current: Int, count: Int, forward: Bool) -> Int {
        guard count > 0 else { return 0 }
        let delta = forward ? 1 : -1
        return ((current + delta) % count + count) % count
    }
}
