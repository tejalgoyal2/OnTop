// OnTopApp.swift
// @main entry point — minimal by design.
// All real work is delegated to AppDelegate.

import SwiftUI

@main
struct OnTopApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // A Settings scene is required to prevent SwiftUI from creating a
        // default window. We supply an empty view — the real preferences
        // window is an NSWindow opened by AppDelegate.
        Settings {
            EmptyView()
        }
    }
}
