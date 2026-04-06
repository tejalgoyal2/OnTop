// PinnedWindowsStore.swift
// Central state — the list of currently pinned windows (max 3).

import CoreGraphics
import AppKit

// MARK: - PinLevel

/// Priority levels for pinned windows.
/// Higher level = higher CGWindowLevel = stays above lower-level pinned windows.
enum PinLevel: Int, CaseIterable, Equatable {
    case one   = 1
    case two   = 2
    case three = 3

    var displayName: String { "Level \(rawValue)" }

    /// The actual CGWindowLevel assigned to windows at this priority.
    /// kCGFloatingWindowLevel (3) is above all normal app windows.
    /// We step up by 1 per level so they naturally order among each other.
    var cgWindowLevel: CGWindowLevel {
        CGWindowLevel(kCGFloatingWindowLevel) + CGWindowLevel(rawValue - 1)
    }
}

// MARK: - PinnedWindow

/// A snapshot of a window at the moment it was pinned.
final class PinnedWindow {
    let windowID: CGWindowID
    let axElement: AXUIElement
    let appName: String
    let windowTitle: String
    let pid: pid_t
    var level: PinLevel

    init(
        windowID: CGWindowID,
        axElement: AXUIElement,
        appName: String,
        windowTitle: String,
        pid: pid_t,
        level: PinLevel = .one
    ) {
        self.windowID    = windowID
        self.axElement   = axElement
        self.appName     = appName
        self.windowTitle = windowTitle
        self.pid         = pid
        self.level       = level
    }

    /// A short display label shown in the menu.
    var menuLabel: String {
        let title = windowTitle.isEmpty ? appName : windowTitle
        let maxLen = 40
        if title.count > maxLen {
            return String(title.prefix(maxLen)) + "…"
        }
        return title
    }
}

// MARK: - PinnedWindowsStore

/// Single source of truth for all pinned windows.
/// Max capacity: 3 windows. All mutations happen on the main thread.
final class PinnedWindowsStore {
    static let shared = PinnedWindowsStore()
    private init() {}

    private(set) var windows: [PinnedWindow] = []

    var count: Int { windows.count }
    var isFull: Bool { windows.count >= 3 }
    var isEmpty: Bool { windows.isEmpty }

    // MARK: Queries

    func isPinned(windowID: CGWindowID) -> Bool {
        windows.contains { $0.windowID == windowID }
    }

    func window(for windowID: CGWindowID) -> PinnedWindow? {
        windows.first { $0.windowID == windowID }
    }

    // MARK: Mutations

    @discardableResult
    func add(_ window: PinnedWindow) -> Bool {
        guard !isFull, !isPinned(windowID: window.windowID) else { return false }
        windows.append(window)
        return true
    }

    func remove(windowID: CGWindowID) {
        windows.removeAll { $0.windowID == windowID }
    }

    func removeAll() {
        windows.removeAll()
    }

    func setLevel(_ level: PinLevel, for windowID: CGWindowID) {
        window(for: windowID)?.level = level
    }
}
