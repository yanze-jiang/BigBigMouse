import AppKit
import ScrollCore

// Uses the production ApplicationLifecycle, but a separate temporary bundle ID.
// Never creates an event tap or requests accessibility permission.
@MainActor
final class SmokeDelegate: NSObject, NSApplicationDelegate {
    private let lifecycle = ApplicationLifecycle()

    func applicationDidFinishLaunching(_ notification: Notification) {
        record("launched")
        lifecycle.start {
            self.record("ready")
            if RelaunchRequest.parentProcessID(in: CommandLine.arguments) != nil {
                NSApp.terminate(nil)
            } else {
                self.lifecycle.restart()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) { record("terminated") }

    private func record(_ event: String) {
        let log = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("events.log")
        let role = RelaunchRequest.parentProcessID(in: CommandLine.arguments) == nil ? "parent" : "replacement"
        do {
            let handle = try FileHandle(forWritingTo: log)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data("\(ProcessInfo.processInfo.processIdentifier) \(role) \(event)\n".utf8))
        } catch {
            fatalError("Cannot record lifecycle event: \(error)")
        }
    }
}

@main
struct Smoke {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = SmokeDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
