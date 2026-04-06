// PermissionsManager.swift
// Checks for and prompts the user to grant Accessibility + Screen Recording permissions.
//
// Accessibility:    Required to read the frontmost window via AXUIElement.
// Screen Recording: Required to capture window pixels via CGWindowListCreateImageFromArray
//                   (mandatory on macOS 14.0+, but we request early for a smooth UX).

import AppKit
import ApplicationServices
import CoreGraphics

final class PermissionsManager {
    static let shared = PermissionsManager()
    private init() {}

    // MARK: - Permission checks

    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    var hasScreenRecording: Bool {
        // CGPreflightScreenCaptureAccess returns true when the user has already granted
        // Screen Recording — it does NOT prompt or show any system dialog.
        CGPreflightScreenCaptureAccess()
    }

    // MARK: - Request flows

    /// Call once at launch. Requests Accessibility first; Screen Recording is handled
    /// lazily in requestScreenRecordingIfNeeded() (called just before first pin).
    func requestIfNeeded() {
        guard !hasAccessibility else { return }

        // Register the app in the Accessibility list without triggering the
        // system sheet (prompt: false). We show our own alert instead, which
        // is less noisy — especially during development when the binary changes
        // on every Xcode rebuild and macOS would otherwise re-prompt every time.
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        // Show our own explanatory alert with a direct link to the pane
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                OnTop needs Accessibility access to read which window is in front \
                so it can pin it above all others.

                Open System Settings → Privacy & Security → Accessibility, \
                then enable OnTop.

                (If OnTop is already listed there, toggle it OFF then back ON — \
                macOS requires this after every app update.)
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(
                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                )
            }
        }
    }

    /// Call just before the first overlay is created.
    /// CGRequestScreenCaptureAccess() shows the system Sheet — this is the correct
    /// way to trigger it without sandbox (we don't have a sandbox entitlement).
    func requestScreenRecordingIfNeeded() {
        guard !hasScreenRecording else { return }
        // This call triggers the system permission sheet on first run.
        // On subsequent runs where the user denied, it opens System Settings.
        CGRequestScreenCaptureAccess()
    }

}
