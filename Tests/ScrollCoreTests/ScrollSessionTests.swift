import ScrollCore

@MainActor
struct ScrollSessionTests {
    @MainActor private final class Harness {
        var permission = false
        var canStart = true
        var tapRunning = false
        var attempts = 0
        lazy var session = ScrollSession(
            enabled: true,
            hasPermission: { self.permission },
            startTap: {
                self.attempts += 1
                self.tapRunning = self.canStart
                return self.canStart
            },
            stopTap: { self.tapRunning = false }
        )
    }

    func missingPermissionNeverStartsTheTap() throws {
        let harness = Harness()
        harness.session.refresh()
        try expect(harness.session.state == .needsPermission)
        try expect(harness.attempts == 0)
        try expect(!harness.tapRunning)
    }

    func permissionGrantStartsWithoutRelaunch() throws {
        let harness = Harness()
        harness.session.refresh()
        harness.permission = true
        harness.session.refresh()
        try expect(harness.session.state == .active)
        try expect(harness.tapRunning)
    }

    func disableStopsAndStaysStoppedAcrossRefreshes() throws {
        let harness = Harness()
        harness.permission = true
        harness.session.refresh()
        harness.session.setEnabled(false)
        harness.session.refresh()
        try expect(harness.session.state == .disabled)
        try expect(!harness.tapRunning)
        try expect(harness.attempts == 1)
        harness.session.setEnabled(true)
        try expect(harness.session.state == .active)
    }

    func revokingPermissionStopsAnActiveTap() throws {
        let harness = Harness()
        harness.permission = true
        harness.session.refresh()
        harness.permission = false
        harness.session.refresh()
        try expect(harness.session.state == .needsPermission)
        try expect(!harness.tapRunning)
    }

    func startupFailureIsReportedAndCanRecover() throws {
        let harness = Harness()
        harness.permission = true
        harness.canStart = false
        harness.session.refresh()
        try expect(harness.session.state == .failed)
        try expect(!harness.tapRunning)
        harness.canStart = true
        harness.session.refresh()
        try expect(harness.session.state == .active)
    }

    func disabledAtLaunchNeedsNoPermission() throws {
        var attemptedStart = false
        let session = ScrollSession(enabled: false, hasPermission: { false }, startTap: {
            attemptedStart = true
            return true
        }, stopTap: {})
        session.refresh()
        try expect(session.state == .disabled)
        try expect(!attemptedStart)
    }
}
