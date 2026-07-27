import SwiftUI

@main
struct SleepTokenKBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // The host app is deliberately dark-only (see Theme.swift). The
                // keyboard extension is unaffected and follows the system appearance.
                // Tint lives on ContentView's NavigationStack, inside a tracked
                // body, so it rethemes reliably; a copy here would not.
                .preferredColorScheme(.dark)
        }
    }
}
