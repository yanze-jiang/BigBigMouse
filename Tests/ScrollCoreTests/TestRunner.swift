import Foundation

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #filePath, line: UInt = #line) throws {
    guard condition() else { throw CheckFailure(description: "Expectation failed at \(file):\(line)") }
}

func require<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { throw CheckFailure(description: "Missing value at \(file):\(line)") }
    return value
}

// A small executable harness keeps tests runnable with Command Line Tools alone;
// Apple's XCTest and Swift Testing frameworks require a full Xcode installation.
@main
struct TestRunner {
    @MainActor static func main() {
        let scroll = ScrollReverserTests()
        let session = ScrollSessionTests()
        let location = ApplicationLocationTests()
        let checks: [(String, () throws -> Void)] = [
            ("wheel: all vertical representations and both directions", scroll.reversesAllVerticalRepresentations),
            ("wheel: horizontal deltas and modifier keys preserved", scroll.preservesHorizontalDeltasAndModifierKeys),
            ("trackpad: continuous and momentum events unchanged", scroll.leavesTrackpadAndMomentumEventsByteForByteUnchanged),
            ("trackpad: phased gestures preserved", scroll.preservesPhasedGesturesEvenIfContinuousFlagIsMissing),
            ("disabled: wheel events unchanged", scroll.disabledLeavesWheelEventUntouched),
            ("wheel: zero vertical delta preserved", scroll.zeroVerticalDeltaDoesNotCreateMovement),
            ("unrelated events unchanged", scroll.unrelatedEventsRemainUnchanged),
            ("permission missing: no tap starts", session.missingPermissionNeverStartsTheTap),
            ("permission granted: starts without relaunch", session.permissionGrantStartsWithoutRelaunch),
            ("disable: tap stops across refreshes", session.disableStopsAndStaysStoppedAcrossRefreshes),
            ("permission revoked: active tap stops", session.revokingPermissionStopsAnActiveTap),
            ("tap failure: reported and recoverable", session.startupFailureIsReportedAndCanRecover),
            ("disabled launch: no permission needed", session.disabledAtLaunchNeedsNoPermission),
            ("installation: system and user Applications folders allowed", location.allowsSystemAndUserApplicationsDirectories),
            ("installation: external and lookalike paths rejected", location.rejectsDownloadsDiskImagesBuildsAndPrefixLookalikes),
            ("installation: symbolic link cannot disguise external copy", location.symbolicLinkDoesNotDisguiseAnExternalCopyAsInstalled),
            ("instances: installed and build copies distinguished", location.distinguishesInstalledAndBuildCopiesWithTheSameName),
            ("relaunch: invalid parent arguments rejected", location.validatesRelaunchParentBeforeWaiting)
        ]
        var failures = 0
        for (name, check) in checks {
            do {
                try check()
                print("PASS \(name)")
            } catch {
                failures += 1
                print("FAIL \(name): \(error)")
            }
        }
        print("\(checks.count - failures)/\(checks.count) checks passed")
        if failures > 0 { exit(1) }
    }
}
