import SwiftUI
import ARKit

/// Main scanning view. Shows different UI based on scan state:
/// - Idle: start button and device compatibility check
/// - Scanning: AR camera feed with guidance overlay
/// - Processing: animated processing screen
/// - Completed: scan summary and shortcut to 3D Viewer
/// - Failed: error message with retry
struct ScannerView: View {
    @ObservedObject var viewModel: ScannerViewModel
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // AR Camera View (always mounted in hierarchy to ensure ARSCNView is ready)
                ARViewContainer(viewModel: viewModel)
                    .ignoresSafeArea()
                    .opacity(viewModel.scanSession.state == .scanning ? 1.0 : 0.0)

                switch viewModel.scanSession.state {
                case .idle:
                    idleView
                case .scanning:
                    GuidanceOverlayView(viewModel: viewModel)
                case .processing:
                    ProcessingView(
                        progress: viewModel.processingProgress,
                        stageText: viewModel.processingStage
                    )
                case .completed:
                    completedView
                case .failed(let message):
                    failedView(message: message)
                }
            }
            .navigationTitle("Face Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.scanSession.state == .scanning {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Stop") {
                            viewModel.stopScanning()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    // MARK: - Idle State

    private var idleView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "faceid")
                .font(.system(size: 80))
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 12) {
                Text("TrueDepth 3D Scanner")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("Position your face in frame and follow\nthe on-screen guidance to capture a\nhigh-accuracy 3D face mesh.")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
            }

            if viewModel.isARFaceTrackingSupported {
                Button {
                    viewModel.startScanning()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                        Text("Start Scan")
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 48)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(.orange)
                    Text("TrueDepth camera not available")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("Requires iPhone X or later with Face ID")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .padding()
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
    }

    // MARK: - Completed State

    private var completedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Scan Complete")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text("\(viewModel.scanSession.finalVertices.count) vertices captured")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Button {
                selectedTab = 1
            } label: {
                HStack {
                    Image(systemName: "cube.fill")
                    Text("View 3D Model")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
            }

            Button("New Scan") {
                viewModel.resetScan()
            }
            .font(.subheadline)
            .foregroundStyle(.cyan)
        }
    }

    // MARK: - Failed State

    private func failedView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 56))
                .foregroundStyle(.red)

            Text("Scan Failed")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                viewModel.resetScan()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundStyle(.black)
                .padding(.vertical, 14)
                .padding(.horizontal, 32)
                .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }
}
