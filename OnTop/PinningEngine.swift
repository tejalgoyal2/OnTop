// PinningEngine.swift
// Stub: pinning logic not yet implemented.
//
// The store tracks which windows should be pinned, but we don't yet have a
// mechanism to actually float them above every other window.
// Upcoming commits will fill this in.

import AppKit
import CoreGraphics

final class PinningEngine {
    static let shared = PinningEngine()
    private init() {}

    /// Attempt to float the given window above all others.
    @discardableResult
    func pin(window: PinnedWindow) -> Bool {
        // TODO: implement cross-process window elevation
        print("[PinningEngine] pin() not yet implemented for windowID \(window.windowID)")
        return false
    }

    /// Restore the window's normal Z-order.
    func unpin(windowID: CGWindowID) {
        // TODO: restore window level
    }

    /// Restore every pinned window to normal level — called on app quit.
    func unpinAll() {
        // TODO: restore all window levels
    }

    /// Re-apply elevation for every pinned window (e.g. after an app-switch).
    func reapplyAll() {
        for w in PinnedWindowsStore.shared.windows {
            pin(window: w)
        }
    }
}
