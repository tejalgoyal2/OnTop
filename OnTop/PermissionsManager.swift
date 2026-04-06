// PermissionsManager.swift
// Checks for and prompts the user to grant Accessibility permission.
// AX access is required to read the frontmost window via AXUIElement.

import AppKit
import ApplicationServices

final class PermissionsManager {
    static let shared = PermissionsManager()
    private init() {}

    var hasAccessibility: Bool {
        AXIsProcessTrusted()
    }

    /// If permission is already granted, returns immediately.
    /// Otherwise shows an alert offering to open System Settings.
    func requestIfNeeded() {
        guard !hasAccessibility else { return }

        // Trigger the system prompt (marks our app in the Accessibility list)
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)

        // Also show our own explanatory alert with a direct link to the pane
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = """
                OnTop needs Accessibility access to read which window is in front \
                so it can pin it above all others.

                Open System Settings → Privacy & Security → Accessibility, \
                then enable OnTop.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Polls until permission is granted, then calls the completion handler.
    /// Useful to re-check after the user has opened System Settings.
    func waitForPermission(completion: @escaping () -> Void) {
        guard !hasAccessibility else { completion(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.waitForPermission(completion: completion)
        }
    }
}
