// ShortcutManager.swift
// Registers the global keyboard shortcut using the KeyboardShortcuts package.
// Default: ⌃⌥P  (Control + Option + P) — unlikely to conflict with common shortcuts.

import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The single shortcut for toggling pin/unpin on the frontmost window.
    static let togglePin = Self("togglePin", default: .init(.p, modifiers: [.control, .option]))
}

final class ShortcutManager {
    static let shared = ShortcutManager()
    private init() {}

    func setup(onTogglePin: @escaping () -> Void) {
        KeyboardShortcuts.onKeyUp(for: .togglePin) {
            onTogglePin()
        }
    }
}
