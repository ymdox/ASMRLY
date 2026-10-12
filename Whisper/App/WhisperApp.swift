import SwiftUI

@main
struct WhisperApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.Colors.lavender)
        }
    }
}
