import SwiftUI

/// Overlay view displayed during active scanning.
/// Shows the current direction instruction, progress ring, direction indicator,
/// face detection status, and completed direction checkmarks.
struct GuidanceOverlayView: View {
    let direction: ScanDirection
    let progress: Double
    let directionProgress: Double
    let isFaceDetected: Bool
    let completedDirections: Set<ScanDirection>

    var body: some View {
        VStack {
            // Top: face detection indicator
            faceDetectionBadge
                .padding(.top, 60)

            Spacer()

            // Center: direction indicator with progress ring
            directionIndicator

            Spacer()

            // Bottom: direction checklist + instruction
            VStack(spacing: 16) {
                directionChecklist
                instructionLabel
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Face Detection Badge

    private var faceDetectionBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isFaceDetected ? Color.green : Color.red)
                .frame(width: 10, height: 10)

            Text(isFaceDetected ? "Face Detected" : "No Face Detected")
                .font(.caption.bold())
                .foregroundStyle(isFaceDetected ? .green : .red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Direction Indicator

    private var directionIndicator: some View {
        ZStack {
            // Outer progress ring (overall scan progress)
            Circle()
                .stroke(.white.opacity(0.2), lineWidth: 6)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Inner progress ring (current direction capture)
            Circle()
                .trim(from: 0, to: directionProgress)
                .stroke(.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: directionProgress)

            // Direction icon
            Image(systemName: direction.systemImage)
                .font(.system(size: 44))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, value: direction)
        }
    }

    // MARK: - Direction Checklist

    private var directionChecklist: some View {
        HStack(spacing: 16) {
            ForEach(ScanDirection.allCases) { dir in
                VStack(spacing: 4) {
                    Image(systemName: dir.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(
                            completedDirections.contains(dir) ? .green :
                            dir == direction ? .cyan : .gray
                        )

                    if completedDirections.contains(dir) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                    } else {
                        Circle()
                            .stroke(dir == direction ? Color.cyan : Color.gray, lineWidth: 1.5)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Instruction Label

    private var instructionLabel: some View {
        Text(direction.instruction)
            .font(.title3.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .animation(.easeInOut, value: direction)
    }
}
