import SwiftUI

/// Application entry point using SwiftUI lifecycle.
/// Forces dark mode and initializes the shared LoggerService on launch.
@main
struct TrueDepth3DScannerApp: App {
    init() {
        LoggerService.shared.log("Application launched", level: .info)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
