import CoreGraphics
import Foundation

public struct WindowInfo: Identifiable, Equatable, Sendable {
    public var id: CGWindowID { windowID }

    public let windowID: CGWindowID
    public let ownerPID: pid_t
    public let ownerName: String
    public let title: String
    public let frame: CGRect
    public let layer: Int

    public init(windowID: CGWindowID, ownerPID: pid_t, ownerName: String, title: String, frame: CGRect, layer: Int) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.ownerName = ownerName
        self.title = title
        self.frame = frame
        self.layer = layer
    }
}
