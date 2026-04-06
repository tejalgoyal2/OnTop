// WindowTracker.swift
// Two responsibilities only:
//   1. Detect the frontmost window the user wants to pin.
//   2. Clean up when pinned windows close / apps quit.
//
// We no longer need any re-raise logic here. The OverlayWindowManager owns
// its windows at floating level — that's permanent. No timer needed for "on top".

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
        guard let app = NSWorkspace.shared.frontmostApplication else {
            NSLog("OnTop: no frontmost application")
            return nil
        }
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            NSLog("OnTop: frontmost app is OnTop itself — focus another window first")
            return nil
        }

        NSLog("OnTop: frontmost app is %@ (pid %d)", app.localizedName ?? "?", app.processIdentifier)

        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        let axResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)
        guard axResult == .success, let windowElement = windowRef as! AXUIElement? else {
            NSLog("OnTop: AXUIElementCopyAttributeValue failed (%d) — accessibility may not be granted", axResult.rawValue)
            return nil
        }

        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(windowElement, &windowID) == .success, windowID != 0 else {
            NSLog("OnTop: _AXUIElementGetWindow failed — could not get CGWindowID")
            return nil
        }

        var titleRef: CFTypeRef?
        let title: String
        if AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleRef) == .success,
           let str = titleRef as? String, !str.isEmpty {
            title = str
        } else {
            title = app.localizedName ?? "Unknown"
        }

        NSLog("OnTop: detected window '%@' (ID %u) from %@", title, windowID, app.localizedName ?? "?")
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
            OverlayWindowManager.shared.removeOverlay(for: w.windowID)
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
            OverlayWindowManager.shared.removeOverlay(for: w.windowID)
            store.remove(windowID: w.windowID)
            removed = true
        }

        if removed {
            DispatchQueue.main.async { [weak self] in self?.onWindowRemoved?() }
        }
    }
}
