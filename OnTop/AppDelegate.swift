// AppDelegate.swift
// Wires everything together at launch.

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    static weak var shared: AppDelegate?

    private var menuBarController: MenuBarController?
    private var preferencesWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Hide from Dock (belt-and-suspenders alongside LSUIElement in Info.plist)
        NSApp.setActivationPolicy(.accessory)

        // Prompt for accessibility if not yet granted — the actual pin action
        // in MenuBarController.togglePinFrontmost() re-checks before each use,
        // so we can proceed with creating the menu bar icon immediately.
        if !PermissionsManager.shared.hasAccessibility {
            PermissionsManager.shared.requestIfNeeded()
        }

        launchApp()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the tracker (timers + observers). No OS-level window state to restore
        // since our overlay windows are owned by us — closing them is enough,
        // and they close automatically when our process exits.
        WindowTracker.shared.stop()
    }

    // MARK: - Preferences window

    func openPreferences() {
        if preferencesWindow == nil {
            let hostingController = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "OnTop Preferences"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            preferencesWindow = window
        }

        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
        preferencesWindow?.center()
    }

    // MARK: - Private

    private func launchApp() {
        menuBarController = MenuBarController()
        WindowTracker.shared.start()

        ShortcutManager.shared.setup { [weak self] in
            self?.menuBarController?.togglePinFrontmost()
        }
    }
}
