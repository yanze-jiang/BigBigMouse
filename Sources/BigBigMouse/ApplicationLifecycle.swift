import AppKit
import ScrollCore

@MainActor
final class ApplicationLifecycle {
    private var isRelaunching = false

    func start(_ completion: @escaping @MainActor () -> Void) {
        // A replacement instance waits until its own previous process exits.
        // Return from didFinishLaunching immediately so NSWorkspace can notify
        // that previous process that the replacement has launched successfully.
        if let pid = RelaunchRequest.parentProcessID(in: CommandLine.arguments),
           pid != ProcessInfo.processInfo.processIdentifier,
           let parent = NSRunningApplication(processIdentifier: pid),
           parent.bundleIdentifier == Bundle.main.bundleIdentifier,
           let parentURL = parent.bundleURL,
           ApplicationLocation.isSameCopy(parentURL, Bundle.main.bundleURL) {
            Task { @MainActor in
                for _ in 0..<100 {
                    if parent.isTerminated {
                        continueLaunch(completion)
                        return
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
                showError("旧进程还未退出", detail: "请从菜单栏退出 BigBigMouse，再从「应用程序」打开。")
                NSApp.terminate(nil)
            }
            return
        }
        continueLaunch(completion)
    }

    private func continueLaunch(_ completion: @escaping @MainActor () -> Void) {
        let locations = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
            + FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
        let developmentLaunch = CommandLine.arguments.contains("--allow-development-location")
        guard developmentLaunch || ApplicationLocation.isInstalled(Bundle.main.bundleURL, in: locations) else {
            let alert = NSAlert()
            alert.messageText = "请先放入「应用程序」"
            alert.informativeText = "将 BigBigMouse 拖入「应用程序」，再从那里打开和授权，避免授权的应用与实际运行的副本不一致。\n\n当前位置：\n\(Bundle.main.bundlePath)"
            alert.addButton(withTitle: "在 Finder 中显示")
            alert.addButton(withTitle: "退出")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            NSApp.terminate(nil)
            return
        }

        if let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            if let existingURL = existing.bundleURL,
               ApplicationLocation.isSameCopy(existingURL, Bundle.main.bundleURL) {
                existing.activate(options: [])
            } else {
                let alert = NSAlert()
                alert.messageText = "另一份 BigBigMouse 正在运行"
                alert.informativeText = "请先从菜单栏退出正在运行的副本，再重新打开本应用。\n\n正在运行：\n\(existing.bundleURL?.path ?? "无法确定位置")\n\n这次打开：\n\(Bundle.main.bundlePath)"
                if existing.bundleURL != nil { alert.addButton(withTitle: "显示正在运行的副本") }
                alert.addButton(withTitle: "关闭")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn, let url = existing.bundleURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            NSApp.terminate(nil)
            return
        }
        completion()
    }

    func restart() {
        guard !isRelaunching else { return }
        isRelaunching = true
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["--relaunch-after", String(ProcessInfo.processInfo.processIdentifier)]
        if CommandLine.arguments.contains("--allow-development-location") {
            configuration.arguments.append("--allow-development-location")
        }
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { [weak self] app, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isRelaunching = false
                    self.showError("暂时无法重新打开", detail: error.localizedDescription + "\n请手动退出后，从「应用程序」再次打开。")
                } else if app != nil {
                    NSApp.terminate(nil)
                } else {
                    self.isRelaunching = false
                    self.showError("暂时无法重新打开", detail: "请手动退出后，从「应用程序」再次打开。")
                }
            }
        }
    }

    private func showError(_ title: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
