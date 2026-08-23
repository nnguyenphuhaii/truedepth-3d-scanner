import SwiftUI

/// Responsive guidance overlay:
/// - Real-time face tracking status
/// - Interactive direction switcher: tap any angle badge to select it manually
/// - Visual progress indicator
/// - Large "Chụp Góc Này" shutter button for instant 1-tap capture
/// - "Hoàn tất & Xem 3D" button
struct GuidanceOverlayView: View {
    @ObservedObject var viewModel: ScannerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            topBar
                .padding(.top, 50)
                .padding(.horizontal, 20)

            Spacer()

            // Center Guidance
            centerGuidance

            Spacer()

            // Bottom Controls
            bottomControls
                .padding(.bottom, 25)
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

                Text(viewModel.isFaceDetected ? "Đã nhận diện mặt" : "Không tìm thấy mặt")
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
        VStack(spacing: 16) {
            ZStack {
                // Outer ring (overall 5-direction scan progress)
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 8)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: viewModel.scanSession.progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [.cyan, .blue, .purple, .cyan]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: viewModel.scanSession.progress)

                // Inner hold ring (fills green when angle matches)
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 5)
                    .frame(width: 115, height: 115)

                Circle()
                    .trim(from: 0, to: viewModel.directionProgress)
                    .stroke(.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 115, height: 115)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: viewModel.directionProgress)

                // Direction Icon
                Image(systemName: viewModel.scanSession.currentDirection.systemImage)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(viewModel.directionProgress > 0 ? .green : .white)
                    .scaleEffect(viewModel.directionProgress > 0 ? 1.15 : 1.0)
                    .animation(.spring(response: 0.25), value: viewModel.directionProgress)
            }

            // Direction text
            VStack(spacing: 4) {
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
        VStack(spacing: 14) {
            // Interactive 5-Direction Checklist (Tap to switch angle directly)
            HStack(spacing: 10) {
                ForEach(ScanDirection.allCases) { dir in
                    Button {
                        viewModel.selectDirection(dir)
                    } label: {
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
                                    .stroke(dir == viewModel.scanSession.currentDirection ? Color.cyan : Color.gray.opacity(0.4), lineWidth: 1.5)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            dir == viewModel.scanSession.currentDirection ?
                                Color.cyan.opacity(0.15) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            // Action Buttons
            HStack(spacing: 10) {
                // Large Manual Capture Shutter
                Button {
                    viewModel.manualCaptureCurrentFrame()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.shutter.button.fill")
                            .font(.title3)
                        Text("Chụp Góc Này")
                            .font(.headline)
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [.cyan, .blue.opacity(0.8)], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .shadow(color: .cyan.opacity(0.4), radius: 8, x: 0, y: 3)
                }

                // Finish early button if at least 1 angle was captured
                if !viewModel.scanSession.capturedFrames.isEmpty {
                    Button {
                        viewModel.finishScanEarly()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cube.fill")
                            Text("Xem 3D (\(viewModel.scanSession.capturedFrames.count))")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.green)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 15)
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}
