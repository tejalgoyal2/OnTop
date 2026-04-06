// MenuBarController.swift
// Owns the NSStatusItem and builds the menu fresh on every open (NSMenuDelegate).

import AppKit
import ApplicationServices

final class MenuBarController: NSObject {

    // MARK: - Properties

    private let statusItem: NSStatusItem
    private let store   = PinnedWindowsStore.shared
    private let overlay = OverlayWindowManager.shared
    private let tracker = WindowTracker.shared

    private(set) var isPaused = false

    // MARK: - Init

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "OnTop")
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        tracker.onWindowRemoved = { [weak self] in
            self?.syncStatusIcon()
        }
    }

    // MARK: - Public API

    func togglePinFrontmost() {
        guard PermissionsManager.shared.hasAccessibility else {
            PermissionsManager.shared.requestIfNeeded()
            return
        }

        guard let info = tracker.frontmostWindow() else {
            NSSound(named: "Basso")?.play()
            return
        }

        if store.isPinned(windowID: info.windowID) {
            doUnpin(windowID: info.windowID)
            playUnpinSound()
        } else if store.isFull {
            NSSound(named: "Basso")?.play()
            showCapacityAlert()
            return
        } else {
            // Ensure Screen Recording permission before the first capture attempt
            PermissionsManager.shared.requestScreenRecordingIfNeeded()

            let pw = PinnedWindow(
                windowID:    info.windowID,
                axElement:   info.axElement,
                appName:     info.appName,
                windowTitle: info.windowTitle,
                pid:         info.pid
            )
            store.add(pw)
            overlay.createOverlay(for: pw)
            playPinSound()
        }

        syncStatusIcon()
    }

    // MARK: - Core pin/unpin

    /// Single authoritative unpin that removes overlay + store entry.
    private func doUnpin(windowID: CGWindowID) {
        overlay.removeOverlay(for: windowID)
        store.remove(windowID: windowID)
    }

    // MARK: - Private helpers

    private func playPinSound()   { NSSound(named: "Tink")?.play() }
    private func playUnpinSound() { NSSound(named: "Pop")?.play()  }

    private func syncStatusIcon() {
        let name = store.isEmpty ? "pin" : "pin.fill"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "OnTop")
        statusItem.button?.image?.isTemplate = true
    }

    private func showCapacityAlert() {
        let alert = NSAlert()
        alert.messageText = "Maximum Pinned Windows Reached"
        alert.informativeText = "OnTop supports up to 3 pinned windows. Unpin one before adding another."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Menu construction

    private func buildMenu(into menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(makeItem("Pin / Unpin Frontmost Window") { [weak self] in
            self?.togglePinFrontmost()
        })

        menu.addItem(.separator())

        if store.isEmpty {
            let empty = NSMenuItem(title: "No Pinned Windows", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let header = NSMenuItem(title: "Pinned Windows", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for window in store.windows {
                let item = NSMenuItem(title: "  \(window.menuLabel)", action: nil, keyEquivalent: "")
                item.submenu = buildWindowSubmenu(for: window)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        let pauseTitle = isPaused ? "Resume All Pins" : "Pause All Pins"
        menu.addItem(makeItem(pauseTitle) { [weak self] in self?.togglePause() })
        menu.addItem(makeItem("Unpin All")  { [weak self] in self?.unpinAll()    })

        menu.addItem(.separator())

        menu.addItem(makeItem("Preferences…") { AppDelegate.shared?.openPreferences() })

        let loginItem = makeItem("Launch at Login") { [weak self] in self?.toggleLaunchAtLogin() }
        loginItem.state = LoginItemManager.shared.isEnabled ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(makeItem("Quit OnTop") { NSApp.terminate(nil) })
    }

    private func buildWindowSubmenu(for window: PinnedWindow) -> NSMenu {
        let sub = NSMenu()

        let infoItem = NSMenuItem(title: window.appName, action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        sub.addItem(infoItem)
        sub.addItem(.separator())

        for level in PinLevel.allCases {
            let item = makeItem(level.displayName) { [weak self] in
                self?.setLevel(level, for: window.windowID)
            }
            item.state = window.level == level ? .on : .off
            sub.addItem(item)
        }

        sub.addItem(.separator())
        sub.addItem(makeItem("Unpin") { [weak self] in
            self?.unpinWindow(windowID: window.windowID)
        })

        return sub
    }

    // MARK: - Actions

    private func setLevel(_ level: PinLevel, for windowID: CGWindowID) {
        store.setLevel(level, for: windowID)
        overlay.updateLevel(windowID: windowID, level: level)
    }

    private func unpinWindow(windowID: CGWindowID) {
        doUnpin(windowID: windowID)
        playUnpinSound()
        syncStatusIcon()
    }

    private func togglePause() {
        isPaused.toggle()
        if isPaused {
            // Hide all overlays without removing them from the store
            overlay.removeAll()
            NSSound(named: "Pop")?.play()
        } else {
            // Recreate overlays for all still-pinned windows
            for w in store.windows { overlay.createOverlay(for: w) }
            NSSound(named: "Tink")?.play()
        }
    }

    private func unpinAll() {
        overlay.removeAll()
        store.removeAll()
        isPaused = false
        playUnpinSound()
        syncStatusIcon()
    }

    private func toggleLaunchAtLogin() {
        LoginItemManager.shared.toggle()
    }
}

// MARK: - NSMenuDelegate

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        buildMenu(into: menu)
    }
}

// MARK: - NSMenuItem closure helper

private final class MenuAction: NSObject {
    let perform: () -> Void
    init(_ perform: @escaping () -> Void) { self.perform = perform }
    @objc func invoke() { perform() }
}

private func makeItem(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
    let target = MenuAction(action)
    let item = NSMenuItem(title: title, action: #selector(MenuAction.invoke), keyEquivalent: "")
    item.target = target
    item.representedObject = target
    return item
}
