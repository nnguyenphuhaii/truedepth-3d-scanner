import SwiftUI

/// Full-screen processing indicator displayed while the mesh is being merged.
/// Uses a custom rotating animation to keep the UI responsive and visually engaging.
struct ProcessingView: View {
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 40) {
                // Animated 3D cube icon
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.cyan, .blue, .purple, .cyan]),
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(rotation))

                    // Inner pulsing icon
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }

                VStack(spacing: 12) {
                    Text("Processing 3D Data...")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("Merging face mesh from multiple angles.\nThis may take a moment.")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                }

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.cyan)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            // Continuous rotation
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            // Pulsing scale
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                scale = 1.1
                opacity = 1.0
            }
        }
    }
}
