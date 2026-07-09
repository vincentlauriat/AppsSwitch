import Testing
@testable import AppsSwitchCore

@Suite struct WindowOrderingTests {
    @Test func initialSelectionSkipsFrontWindowWhenMultipleWindows() {
        #expect(WindowOrdering.initialSelectionIndex(windowCount: 6) == 1)
        #expect(WindowOrdering.initialSelectionIndex(windowCount: 2) == 1)
    }

    @Test func initialSelectionStaysOnFrontWindowWhenSingleOrNoWindow() {
        #expect(WindowOrdering.initialSelectionIndex(windowCount: 1) == 0)
        #expect(WindowOrdering.initialSelectionIndex(windowCount: 0) == 0)
    }

    @Test func advancedIndexWrapsForward() {
        #expect(WindowOrdering.advancedIndex(from: 0, count: 6, forward: true) == 1)
        #expect(WindowOrdering.advancedIndex(from: 5, count: 6, forward: true) == 0)
    }

    @Test func advancedIndexWrapsBackward() {
        #expect(WindowOrdering.advancedIndex(from: 1, count: 6, forward: false) == 0)
        #expect(WindowOrdering.advancedIndex(from: 0, count: 6, forward: false) == 5)
    }

    @Test func advancedIndexStaysPutWithSingleWindow() {
        #expect(WindowOrdering.advancedIndex(from: 0, count: 1, forward: true) == 0)
        #expect(WindowOrdering.advancedIndex(from: 0, count: 1, forward: false) == 0)
    }

    @Test func advancedIndexWithNoWindowsReturnsZero() {
        #expect(WindowOrdering.advancedIndex(from: 0, count: 0, forward: true) == 0)
    }
}
