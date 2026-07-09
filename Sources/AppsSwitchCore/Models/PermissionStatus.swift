public struct PermissionStatus: Equatable, Sendable {
    public var accessibilityGranted: Bool
    public var screenRecordingGranted: Bool

    public init(accessibilityGranted: Bool, screenRecordingGranted: Bool) {
        self.accessibilityGranted = accessibilityGranted
        self.screenRecordingGranted = screenRecordingGranted
    }

    public var allGranted: Bool {
        accessibilityGranted && screenRecordingGranted
    }
}
