// LoginItemManager.swift
// Launch-at-login via SMAppService — the modern native API (macOS 13+).
// No helper app, no third-party package needed.

import ServiceManagement

final class LoginItemManager {
    static let shared = LoginItemManager()
    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail — user can always toggle again.
            // Common cause: running from Xcode (not an installed app bundle).
        }
    }

    func toggle() {
        setEnabled(!isEnabled)
    }
}
