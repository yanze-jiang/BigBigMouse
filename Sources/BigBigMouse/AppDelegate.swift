import AppKit
@preconcurrency import ApplicationServices
import ScrollCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let defaults = UserDefaults.standard
    private let eventTap = ScrollEventTap()
    private let lifecycle = ApplicationLifecycle()
    private var statusItem: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var toggleItem: NSMenuItem!
    private var permissionItem: NSMenuItem!
    private var retryItem: NSMenuItem!
    private var recoveryItem: NSMenuItem!
    private var locationItem: NSMenuItem!
    private var permissionTimer: Timer?
    private var showingGuide = false
    private var hasStarted = false
    private lazy var session = ScrollSession(
        enabled: defaults.bool(forKey: "reverseScrolling"),
        hasPermission: { AXIsProcessTrusted() },
        startTap: { [weak self] in self?.eventTap.start() ?? false },
        stopTap: { [weak self] in self?.eventTap.stop() }
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        lifecycle.start { [weak self] in self?.finishLaunching() }
    }

    private func finishLaunching() {
        defaults.register(defaults: ["reverseScrolling": true])
        buildMenu()
        hasStarted = true
        eventTap.onInterruption = { [weak self] in self?.refresh() }
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(refresh), name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: NSApplication.didBecomeActiveNotification, object: nil)
        refresh()

        if !defaults.bool(forKey: "hasShownWelcome") {
            defaults.set(true, forKey: "hasShownWelcome")
            DispatchQueue.main.async { [weak self] in self?.showWelcome() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        eventTap.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard hasStarted else { return false }
        refresh()
        if session.state == .needsPermission {
            showPermissionGuide()
        } else {
            statusItem?.button?.performClick(nil)
        }
        return false
    }

    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let title = NSMenuItem(title: "BigBigMouse \(version)", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem = addItem("启用鼠标滚轮反转", action: #selector(toggle), to: menu)
        permissionItem = addItem("授予辅助功能权限…", action: #selector(showPermissionGuide), to: menu)
        retryItem = addItem("重试启动", action: #selector(refresh), to: menu)
        recoveryItem = addItem("已授权但仍未生效…", action: #selector(showPermissionRecovery), to: menu)
        locationItem = addItem("在 Finder 中显示当前应用", action: #selector(revealCurrentApplication), to: menu)
        menu.addItem(.separator())
        let quit = addItem("退出 BigBigMouse", action: #selector(quit), to: menu)
        quit.keyEquivalent = "q"
        statusItem.menu = menu
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    @objc private func refresh() {
        guard hasStarted else { return }
        session.refresh()
        updateMenu()
        // Poll only while recovering or waiting for permission. No idle polling
        // while running normally or while the user has disabled the feature.
        let needsRetry = session.state == .needsPermission || session.state == .failed
        if needsRetry && permissionTimer == nil {
            let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            permissionTimer = timer
        } else if !needsRetry {
            permissionTimer?.invalidate()
            permissionTimer = nil
        }
    }

    private func updateMenu() {
        let label: String
        let symbol: String
        switch session.state {
        case .active:
            label = "已开启 · 触控板保持原样"
            symbol = "computermouse.fill"
        case .disabled:
            label = "已关闭"
            symbol = "computermouse"
        case .needsPermission:
            label = "等待辅助功能授权"
            symbol = "exclamationmark.circle"
        case .failed:
            label = "未能启动 · 请重试或重新打开"
            symbol = "exclamationmark.circle"
        }
        statusLine.title = label
        toggleItem.state = session.isEnabled ? .on : .off
        permissionItem.isHidden = session.state != .needsPermission
        retryItem.isHidden = session.state != .failed
        let needsHelp = session.state == .needsPermission || session.state == .failed
        recoveryItem.isHidden = !needsHelp
        locationItem.isHidden = !needsHelp
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "BigBigMouse：\(label)")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "BigBigMouse：\(label)"
            button.setAccessibilityLabel("BigBigMouse：\(label)")
        }
    }

    @objc private func toggle() {
        let enabled = !session.isEnabled
        defaults.set(enabled, forKey: "reverseScrolling")
        session.setEnabled(enabled)
        refresh()
        if session.state == .needsPermission { showPermissionGuide() }
    }

    private func showWelcome() {
        if session.state == .needsPermission {
            showPermissionGuide()
        } else {
            statusItem.button?.performClick(nil)
        }
    }

    @objc private func showPermissionGuide() {
        guard !showingGuide else { return }
        showingGuide = true
        defer { showingGuide = false }
        let alert = NSAlert()
        alert.messageText = "鼠标反向，触控板照常。"
        alert.informativeText = "BigBigMouse 只反转普通鼠标滚轮的上下方向。\n\n首次使用，请在「系统设置 → 隐私与安全性 → 辅助功能」中允许 BigBigMouse。检测到授权后会开启；如果仍在等待，请用菜单栏里的「已授权但仍未生效…」重新打开应用。\n\n请点「＋」添加当前应用：\n\(Bundle.main.bundlePath)"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openAccessibilitySettings()
        }
        refresh()
    }

    @objc private func showPermissionRecovery() {
        refresh()
        guard session.state == .needsPermission || session.state == .failed, !showingGuide else { return }
        showingGuide = true
        defer { showingGuide = false }
        let alert = NSAlert()
        alert.messageText = "系统里已开启，但这里仍在等待？"
        alert.informativeText = "先试一次重新打开应用。\n\n如果更新后仍不生效，请在「辅助功能」列表移除旧的 BigBigMouse 条目，再点「＋」添加下面这份应用并开启权限，然后重新打开。\n\n当前应用：\n\(Bundle.main.bundlePath)\n\n只替换或删除应用，并不一定清除之前的授权记录。"
        alert.addButton(withTitle: "重新打开应用")
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn: lifecycle.restart()
        case .alertSecondButtonReturn: openAccessibilitySettings()
        default: break
        }
    }

    @objc private func revealCurrentApplication() {
        NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
    }

    private func openAccessibilitySettings() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
