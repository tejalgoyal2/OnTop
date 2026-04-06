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
        NSApp.setActivationPolicy(.accessory)
        launchApp()
    }

    /// Prevent the app from quitting when overlay windows are closed (e.g. Unpin All).
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Stop the capture timer first, then the tracker — avoids the timer
        // firing on windows that are mid-teardown.
        OverlayWindowManager.shared.removeAll()
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
