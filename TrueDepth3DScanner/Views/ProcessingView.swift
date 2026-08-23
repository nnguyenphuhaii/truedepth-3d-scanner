import SwiftUI

/// Animated 3D processing view with:
/// - Real-time percentage progress bar (0% -> 100%)
/// - Large glowing digital counter
/// - Dynamic stage descriptions
/// - Rotating gradient particle ring and 3D wireframe icon
struct ProcessingView: View {
    var progress: Double = 0.0
    var stageText: String = "Đang phân tích cấu trúc 3D..."

    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 0.95
    @State private var pulseGlow: Bool = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 35) {
                Spacer()

                // Animated 3D icon with gradient halo
                ZStack {
                    // Outer rotating ring
                    Circle()
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.cyan, .blue, .purple, .pink, .cyan]),
                                center: .center
                            ),
                            lineWidth: 5
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(rotation))
                        .blur(radius: pulseGlow ? 4 : 1)

                    // Inner circle
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 120, height: 120)

                    // 3D Cube Icon
                    Image(systemName: "cube.transparent")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(scale)
                }

                // Title & percentage
                VStack(spacing: 10) {
                    Text("Đang Xử Lý Dữ Liệu 3D")
                        .font(.title2.bold())
                        .foregroundStyle(.white)

                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .contentTransition(.numericText())
                }

                // Smooth Progress Bar
                VStack(spacing: 12) {
                    ZStack(alignment: .leading) {
                        // Background track
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 10)

                        // Filled track
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan, .blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(10, CGFloat(progress) * 280), height: 10)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                            .shadow(color: .cyan.opacity(0.6), radius: 6, x: 0, y: 0)
                    }
                    .frame(width: 280)

                    // Current Stage Description
                    Text(stageText)
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .animation(.easeInOut, value: stageText)
                }

                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scale = 1.05
                pulseGlow = true
            }
        }
    }
}
