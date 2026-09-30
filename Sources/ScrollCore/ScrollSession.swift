/// Coordinates the user's preference with permission and actual tap availability.
/// An enabled preference alone must never be displayed as an active event tap.
@MainActor
public final class ScrollSession {
    public enum State: Equatable {
        case disabled, needsPermission, active, failed
    }

    public private(set) var isEnabled: Bool
    public private(set) var state: State = .disabled
    private let hasPermission: () -> Bool
    private let startTap: () -> Bool
    private let stopTap: () -> Void

    public init(
        enabled: Bool,
        hasPermission: @escaping () -> Bool,
        startTap: @escaping () -> Bool,
        stopTap: @escaping () -> Void
    ) {
        isEnabled = enabled
        self.hasPermission = hasPermission
        self.startTap = startTap
        self.stopTap = stopTap
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        refresh()
    }

    public func refresh() {
        guard isEnabled else {
            stopTap()
            state = .disabled
            return
        }
        guard hasPermission() else {
            stopTap()
            state = .needsPermission
            return
        }
        if startTap() {
            state = .active
        } else {
            stopTap()
            state = .failed
        }
    }
}
