// OverlayWindowManager.swift
//
// The core insight: we can't permanently change another process's window level,
// but we CAN create our own NSWindow at any level we want — because WE own it.
//
// For each pinned window we create a companion OverlayWindow (our process, our
// rules) at kCGFloatingWindowLevel that shows a live 10fps capture of the
// original window via CGImage(windowListFromArrayScreenBounds:windowArray:imageOption:).
// The capture works even when the original window is occluded (behind Xcode, etc.)
// because macOS maintains each window's offscreen backing buffer regardless of visibility.
//
// Performance vs AlwaysOnTop's approach:
//   AlwaysOnTop: AppleScript activate every ~1s (expensive IPC) + 0.5s timer
//   Overlay:     CGImage window capture every 100ms (GPU-backed, cheap)
//                + zero cost for the "always on top" part (our window level is permanent)
//
// Requires: Screen Recording permission (to read another app's window pixels)

import AppKit
import CoreGraphics

// MARK: - OverlayWindowManager

final class OverlayWindowManager {
    static let shared = OverlayWindowManager()

    private var overlays: [CGWindowID: OverlayWindow] = [:]
    private var captureTimer: Timer?

    private init() {}

    // MARK: - Public API

    func createOverlay(for pinnedWindow: PinnedWindow) {
        guard overlays[pinnedWindow.windowID] == nil else { return }

        let overlay = OverlayWindow(
            windowID: pinnedWindow.windowID,
            level:    floatingLevel(for: pinnedWindow.level)
        )
        overlays[pinnedWindow.windowID] = overlay

        // First frame immediately so there's no blank flash on pin
        refreshOverlay(overlay, windowID: pinnedWindow.windowID)

        startTimerIfNeeded()
    }

    func removeOverlay(for windowID: CGWindowID) {
        overlays[windowID]?.tearDown()
        overlays.removeValue(forKey: windowID)
        stopTimerIfEmpty()
    }

    func removeAll() {
        overlays.values.forEach { $0.tearDown() }
        overlays.removeAll()
        captureTimer?.invalidate()
        captureTimer = nil
    }

    func updateLevel(windowID: CGWindowID, level: PinLevel) {
        overlays[windowID]?.level = floatingLevel(for: level)
    }

    // MARK: - Level mapping
    // Level 1 → kCGFloatingWindowLevel (3)   — above all normal apps
    // Level 2 → kCGFloatingWindowLevel + 1   — above Level-1 overlays
    // Level 3 → kCGFloatingWindowLevel + 2   — above Level-2 overlays

    private func floatingLevel(for pinLevel: PinLevel) -> NSWindow.Level {
        let base = Int(CGWindowLevelForKey(.floatingWindow))
        return NSWindow.Level(rawValue: base + pinLevel.rawValue - 1)
    }

    // MARK: - Capture timer

    private func startTimerIfNeeded() {
        guard captureTimer == nil else { return }
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        captureTimer?.tolerance = 0.01
    }

    private func stopTimerIfEmpty() {
        guard overlays.isEmpty else { return }
        captureTimer?.invalidate()
        captureTimer = nil
    }

    private func tick() {
        for (windowID, overlay) in overlays {
            refreshOverlay(overlay, windowID: windowID)
        }
    }

    // MARK: - Per-overlay refresh

    private func refreshOverlay(_ overlay: OverlayWindow, windowID: CGWindowID) {
        // 1. Sync position and size with the original window
        if let frame = nsFrame(for: windowID) {
            if overlay.frame != frame {
                overlay.setFrame(frame, display: false, animate: false)
            }
        }

        // 2. Capture the window's current pixel content
        //    Works even when the window is fully occluded (macOS keeps its backing buffer).
        if let image = captureWindowImage(windowID: windowID) {
            overlay.updateImage(image)
        }
    }

    // MARK: - Image capture

    private func captureWindowImage(windowID: CGWindowID) -> NSImage? {
        let windowList = [NSNumber(value: windowID)] as CFArray
        // CGWindowListCreateImageFromArray was deprecated; use the Swift initializer instead.
        guard let cgImage = CGImage(
            windowListFromArrayScreenBounds: .null,   // no bounds restriction — full window
            windowArray: windowList,
            imageOption: .bestResolution
        ) else { return nil }

        // Build NSImage with the correct point size so NSImageView scales correctly
        // on both Retina and non-Retina displays.
        let rep = NSBitmapImageRep(cgImage: cgImage)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Coordinate conversion
    //
    // CGWindowBounds → top-left origin in global display space
    // NSWindow.frame → bottom-left origin, main display as reference
    //
    // Conversion: NS_y = primaryDisplayHeight - CG_y - CG_height

    private func nsFrame(for windowID: CGWindowID) -> CGRect? {
        guard let list = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements], kCGNullWindowID
        ) as? [[CFString: Any]] else { return nil }

        for info in list {
            guard
                let wid    = info[kCGWindowNumber] as? CGWindowID, wid == windowID,
                let bounds = info[kCGWindowBounds]  as? [String: CGFloat]
            else { continue }

            let cgX = bounds["X"]      ?? 0
            let cgY = bounds["Y"]      ?? 0
            let cgW = bounds["Width"]  ?? 0
            let cgH = bounds["Height"] ?? 0

            // Primary display height is the Y-flip reference point.
            // NSScreen.screens[0] is always the display that contains the menu bar.
            let primaryH = NSScreen.screens.first?.frame.height ?? 0
            return CGRect(x: cgX, y: primaryH - cgY - cgH, width: cgW, height: cgH)
        }
        return nil
    }
}

// MARK: - OverlayWindow

/// A borderless, click-through NSWindow that floats above all normal app windows.
/// Since it belongs to our process we can set its level to anything.
///
/// Click-through (ignoresMouseEvents = true) means pointer events fall straight
/// through to whatever is underneath — the user can still click Xcode normally
/// even though our overlay is visually above it.
final class OverlayWindow: NSWindow {

    private let imageView: NSImageView = {
        let v = NSImageView()
        v.imageScaling = .scaleAxesIndependently
        v.autoresizingMask = [.width, .height]
        return v
    }()

    init(windowID: CGWindowID, level: NSWindow.Level) {
        super.init(
            contentRect: .zero,
            styleMask:   [.borderless],
            backing:     .buffered,
            defer:       true           // defer creation until first display
        )

        self.level              = level
        self.ignoresMouseEvents = true   // click-through
        self.isOpaque           = false
        self.backgroundColor    = .clear
        self.hasShadow          = false
        self.animationBehavior  = .none

        // Show on every Space and on full-screen apps
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        imageView.frame = contentView?.bounds ?? .zero
        contentView?.addSubview(imageView)

        self.orderFrontRegardless()
    }

    func updateImage(_ image: NSImage) {
        imageView.image = image
    }

    func tearDown() {
        orderOut(nil)
        close()
    }
}
