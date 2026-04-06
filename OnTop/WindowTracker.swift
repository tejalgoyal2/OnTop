// WindowTracker.swift
// Two responsibilities only:
//   1. Detect the frontmost window the user wants to pin.
//   2. Clean up when pinned windows close / apps quit.
//
// We no longer need any re-raise logic here. The OverlayWindowManager owns
// its windows at floating level — that's permanent. No timer needed for "on top".

import AppKit

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
        let appName: String
        let windowTitle: String
        let pid: pid_t
    }

    /// Finds the topmost on-screen window that doesn't belong to OnTop.
    /// Uses CGWindowList (no Accessibility permission required) instead of
    /// the AX API, which is unreliable during Xcode development.
    func frontmostWindow() -> FrontmostInfo? {
        let myPID = ProcessInfo.processInfo.processIdentifier

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[CFString: Any]] else {
            NSLog("OnTop: CGWindowListCopyWindowInfo returned nil")
            return nil
        }

        for info in windowList {
            guard
                let pid      = info[kCGWindowOwnerPID] as? pid_t,
                pid != myPID,
                let windowID = info[kCGWindowNumber]    as? CGWindowID,
                let layer    = info[kCGWindowLayer]     as? Int,
                layer == 0   // normal app windows only (skip menu bar, overlays, etc.)
            else { continue }

            // Skip tiny windows (invisible helpers, status-item backing windows, etc.)
            if let bounds = info[kCGWindowBounds] as? [String: CGFloat] {
                let w = bounds["Width"]  ?? 0
                let h = bounds["Height"] ?? 0
                if w < 50 || h < 50 { continue }
            }

            let appName = NSRunningApplication(processIdentifier: pid)?.localizedName
                ?? info[kCGWindowOwnerName] as? String
                ?? "Unknown"

            let windowTitle = info[kCGWindowName] as? String ?? appName

            NSLog("OnTop: detected window '%@' (ID %u) from %@ (pid %d)",
                  windowTitle, windowID, appName, pid)

            return FrontmostInfo(
                windowID:    windowID,
                appName:     appName,
                windowTitle: windowTitle,
                pid:         pid
            )
        }

        NSLog("OnTop: no suitable window found in CGWindowList (%d entries)", windowList.count)
        return nil
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
