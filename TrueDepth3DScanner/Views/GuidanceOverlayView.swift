import SwiftUI

/// Ultra-smooth scanning guidance overlay with:
/// - Real-time face detection indicator
/// - Animated direction guidance icon and instructions
/// - Dual progress rings (overall 5 directions + current direction hold)
/// - Manual "Chụp góc này" shutter button for guaranteed instant capture
/// - "Hoàn tất quét" button for finishing early
struct GuidanceOverlayView: View {
    @ObservedObject var viewModel: ScannerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar: Face detection indicator & direction counter
            topBar
                .padding(.top, 50)
                .padding(.horizontal, 20)

            Spacer()

            // Center: Interactive Direction Indicator & Progress Rings
            centerGuidance

            Spacer()

            // Bottom Bar: Direction Checklist & Control Buttons
            bottomControls
                .padding(.bottom, 30)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isFaceDetected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(viewModel.isFaceDetected ? "Đã nhận diện khuôn mặt" : "Không tìm thấy mặt")
                    .font(.caption.bold())
                    .foregroundStyle(viewModel.isFaceDetected ? .green : .red)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Text("\(viewModel.scanSession.completedDirections.count)/5 Góc")
                .font(.caption.bold())
                .foregroundStyle(.cyan)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    // MARK: - Center Guidance

    private var centerGuidance: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer ring: Overall 5-direction scan progress
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 8)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: viewModel.scanSession.progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .blue, .purple, .cyan]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: viewModel.scanSession.progress)

                // Inner ring: Current direction hold progress
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 125, height: 125)

                Circle()
                    .trim(from: 0, to: viewModel.directionProgress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 125, height: 125)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.directionProgress)

                // Direction icon
                Image(systemName: viewModel.scanSession.currentDirection.systemImage)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(viewModel.directionProgress > 0 ? .green : .white)
                    .scaleEffect(viewModel.directionProgress > 0 ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3), value: viewModel.directionProgress)
            }

            // Direction instruction & hint
            VStack(spacing: 6) {
                Text(viewModel.scanSession.currentDirection.instruction)
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text(viewModel.scanSession.currentDirection.hint)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Direction 5-item checklist
            HStack(spacing: 14) {
                ForEach(ScanDirection.allCases) { dir in
                    VStack(spacing: 4) {
                        Image(systemName: dir.systemImage)
                            .font(.system(size: 16))
                            .foregroundStyle(
                                viewModel.scanSession.completedDirections.contains(dir) ? .green :
                                dir == viewModel.scanSession.currentDirection ? .cyan : .gray
                            )

                        if viewModel.scanSession.completedDirections.contains(dir) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                        } else {
                            Circle()
                                .stroke(dir == viewModel.scanSession.currentDirection ? Color.cyan : Color.gray.opacity(0.5), lineWidth: 1.5)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Action Buttons: Manual Capture & Early Finish
            HStack(spacing: 12) {
                // Manual capture shutter button
                Button {
                    viewModel.manualCaptureCurrentFrame()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.shutter.button.fill")
                            .font(.headline)
                        Text("Chụp Góc Này")
                            .font(.subheadline.bold())
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
                }

                // Finish early if at least 1 frame has been captured
                if !viewModel.scanSession.capturedFrames.isEmpty {
                    Button {
                        viewModel.finishScanEarly()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                            Text("Hoàn tất (\(viewModel.scanSession.capturedFrames.count))")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }
}
