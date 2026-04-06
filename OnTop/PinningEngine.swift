// PinningEngine.swift
//
// Confirmed: CGSSetWindowLevel returns "success" (0) but silently does nothing
// for windows owned by other processes (layerBefore=0, layerAfter=0).
// The WindowServer accepts the call but ignores cross-process level changes
// when using your own connection ID for a foreign window.
//
// Working approach: kAXRaiseAction via the Accessibility subsystem.
// The AX framework has elevated WindowServer permissions (that's exactly why
// Accessibility access is required). kAXRaiseAction reorders the target window
// to the global Z-order front across all apps.
//
// We re-apply on every app-activation event (NSWorkspace notification).
// Limitation discovered later: same-screen activation — the OS finishes
// bringing the newly active app's windows to front AFTER our raise fires,
// overriding it. Cross-screen works fine; same-screen is a race we lose.

import AppKit
import ApplicationServices

final class PinningEngine {
    static let shared = PinningEngine()
    private init() {}

    // MARK: - Raise

    /// Bring a window to the global front via the AX raise action.
    @discardableResult
    func raise(axElement: AXUIElement) -> Bool {
        let result = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        return result == .success
    }

    /// Re-raise all pinned windows in priority order so the highest-level
    /// window ends up on top.
    func reapplyAll() {
        let sorted = PinnedWindowsStore.shared.windows.sorted {
            $0.level.rawValue < $1.level.rawValue
        }
        for w in sorted {
            let axElement = AXUIElementCreateApplication(w.pid)
            raise(axElement: axElement)
        }
    }

    // MARK: - Pin / Unpin

    /// Raise a window immediately when it's pinned — gives instant visual feedback.
    @discardableResult
    func pin(window: PinnedWindow) -> Bool {
        let axElement = AXUIElementCreateApplication(window.pid)
        return raise(axElement: axElement)
    }

    /// Unpinning has no OS-level state to undo — we simply stop re-raising the window.
    func unpin(windowID: CGWindowID) {}

    /// No-op: kAXRaiseAction doesn't make persistent changes.
    func unpinAll() {}
}
