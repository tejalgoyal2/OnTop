// PreferencesView.swift
// A compact SwiftUI preferences panel: shortcut + launch at login.

import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {

    @State private var launchAtLogin = LoginItemManager.shared.isEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }
            } header: {
                Text("General")
            }

            Section {
                KeyboardShortcuts.Recorder("Pin / Unpin Frontmost", name: .togglePin)
            } header: {
                Text("Keyboard Shortcut")
            } footer: {
                Text("Press the shortcut while any window is in focus to pin or unpin it.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Link("Report an Issue", destination: URL(string: "https://github.com/tejalgoyal/ontop/issues")!)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }
}
