// WindowTracker.swift
// Two responsibilities:
//   1. Detect the frontmost window the user wants to pin.
//   2. Clean up when pinned windows close / apps quit.
//
// Raising pinned windows above others is PinningEngine's job.

import AppKit
import ApplicationServices

final class WindowTracker {
    static let shared = WindowTracker()

    var onWindowRemoved: (() -> Void)?

    private var terminationObserver: Any?
    private var sweepTimer: Timer?

    private init() {}

    // MARK: - Lifecycle

    func start() {
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication else { return }
            self?.handleAppTermination(pid: app.processIdentifier)
        }

        // 3-second sweep: catches individual windows closed without the app quitting
        sweepTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.sweepClosedWindows()
        }
        sweepTimer?.tolerance = 1.0
    }

    func stop() {
        if let obs = terminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            terminationObserver = nil
        }
        sweepTimer?.invalidate()
        sweepTimer = nil
    }

    // MARK: - Frontmost window detection

    struct FrontmostInfo {
        let windowID: CGWindowID
        let axElement: AXUIElement
        let appName: String
        let windowTitle: String
        let pid: pid_t
    }

    func frontmostWindow() -> FrontmostInfo? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return nil }

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
              let windowElement = windowRef as! AXUIElement? else { return nil }

        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(windowElement, &windowID) == .success, windowID != 0 else { return nil }

        var titleRef: CFTypeRef?
        let title: String
        if AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef) == .success,
           let str = titleRef as? String, !str.isEmpty {
            title = str
        } else {
            title = app.localizedName ?? "Unknown"
        }

        return FrontmostInfo(
            windowID: windowID,
            axElement: windowElement,
            appName: app.localizedName ?? "Unknown",
            windowTitle: title,
            pid: pid
        )
    }

    // MARK: - Cleanup

    private func handleAppTermination(pid: pid_t) {
        let store = PinnedWindowsStore.shared
        let affected = store.windows.filter { $0.pid == pid }
        guard !affected.isEmpty else { return }

        for w in affected {
            store.remove(windowID: w.windowID)
        }
        onWindowRemoved?()
    }

    private func sweepClosedWindows() {
        let store = PinnedWindowsStore.shared
        guard !store.isEmpty else { return }

        guard let list = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements], kCGNullWindowID
        ) as? [[CFString: Any]] else { return }

        let activeIDs = Set(list.compactMap { $0[kCGWindowNumber] as? CGWindowID })
        var removed = false

        for w in store.windows where !activeIDs.contains(w.windowID) {
            store.remove(windowID: w.windowID)
            removed = true
        }

        if removed {
            DispatchQueue.main.async { [weak self] in self?.onWindowRemoved?() }
        }
    }
}
