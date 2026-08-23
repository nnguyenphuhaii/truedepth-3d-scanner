import SwiftUI

/// Root view with a three-tab layout: Scanner, 3D Viewer, and Developer.
/// Owns the ScannerViewModel as a @StateObject and passes it to child views.
struct ContentView: View {
    @StateObject private var scannerViewModel = ScannerViewModel()
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ScannerView(viewModel: scannerViewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Scanner", systemImage: "camera.fill")
                }
                .tag(0)

            Viewer3DView(viewModel: scannerViewModel)
                .tabItem {
                    Label("3D Viewer", systemImage: "cube.fill")
                }
                .tag(1)

            DeveloperView()
                .tabItem {
                    Label("Developer", systemImage: "terminal.fill")
                }
                .tag(2)
        }
        .tint(.cyan)
        .onChange(of: scannerViewModel.scanSession.state) { _, newState in
            // Auto-switch to 3D Viewer when processing completes
            if newState == .completed {
                withAnimation {
                    selectedTab = 1
                }
            }
        }
    }
}
