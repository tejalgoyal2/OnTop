// PinningEngine.swift
// Applies "always on top" via the private CGSSetWindowLevel API.
//
// Strategy: when a window is pinned, call CGSSetWindowLevel to raise its CG
// window level to kCGFloatingWindowLevel. Re-apply on every app-switch event
// in case macOS resets it (WindowTracker drives the re-apply via didActivateApp).
//
// CGSMainConnectionID() gives us the CG connection for our process.
// The key question: does CGSSetWindowLevel work for windows we don't own?

import AppKit
import CoreGraphics

final class PinningEngine {
    static let shared = PinningEngine()
    private init() {}

    private let cgConnection = CGSMainConnectionID()

    // MARK: - Pin / unpin

    /// Elevates the window to the floating level for its PinLevel.
    @discardableResult
    func pin(window: PinnedWindow) -> Bool {
        let targetLevel = Int32(window.level.cgWindowLevel)
        let result = CGSSetWindowLevel(cgConnection, window.windowID, targetLevel)

        // Log everything — if this doesn't work, the log will tell us why.
        print("[PinningEngine] CGSSetWindowLevel → \(result == 0 ? "SUCCESS" : "FAIL(\(result))")" +
              "  windowID=\(window.windowID)  targetLevel=\(targetLevel)")
        return result == 0
    }

    /// Resets the window back to normal level (kCGNormalWindowLevel = 0).
    func unpin(windowID: CGWindowID) {
        let result = CGSSetWindowLevel(cgConnection, windowID, Int32(kCGNormalWindowLevel))
        if result != 0 {
            print("[PinningEngine] unpin failed: CGSSetWindowLevel returned \(result)")
        }
    }

    /// Resets all pinned windows — called on app quit so nothing stays floating.
    func unpinAll() {
        for w in PinnedWindowsStore.shared.windows {
            unpin(windowID: w.windowID)
        }
    }

    /// Re-assert levels for all pinned windows (called after app-switch events).
    func reapplyAll() {
        for w in PinnedWindowsStore.shared.windows {
            pin(window: w)
        }
    }
}
