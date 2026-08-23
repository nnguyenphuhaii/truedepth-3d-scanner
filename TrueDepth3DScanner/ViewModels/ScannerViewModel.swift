import Foundation
import ARKit
import SceneKit
import Combine
import simd

/// Manages the full face scanning lifecycle with high performance:
/// - 60 FPS SIMD head pose extraction (0 memory allocation)
/// - Throttled UI state updates (15 FPS) to eliminate lag
/// - Baseline angle calibration for effortless relative motion tracking
/// - Automatic & Manual capture modes
final class ScannerViewModel: NSObject, ObservableObject {

    @Published var scanSession = FaceScanSession()
    @Published var isFaceDetected: Bool = false
    @Published var currentYaw: Float = 0.0
    @Published var currentPitch: Float = 0.0
    @Published var directionProgress: Double = 0.0

    private let logger = LoggerService.shared
    private var framesForCurrentDirection: Int = 0
    private let requiredFramesPerDirection: Int = 5  // ~0.08s hold time for instant, effortless capture
    private var isCapturingDirection: Bool = false
    private weak var arView: ARSCNView?

    // Calibration baseline angles
    private var baseYaw: Float = 0.0
    private var basePitch: Float = 0.0
    private var isCalibrated: Bool = false

    // Throttling UI updates to prevent main thread starvation
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.066 // ~15 FPS UI update rate

    /// Whether the device supports ARKit face tracking (TrueDepth camera required).
    var isARFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Store a weak reference to the ARSCNView for session management.
    func setARView(_ view: ARSCNView) {
        self.arView = view
        logger.log("ARView successfully attached", level: .info)
        if scanSession.state == .scanning {
            runARSession()
        }
    }

    /// Run the AR face tracking configuration on the attached ARSCNView.
    private func runARSession() {
        guard let arView = arView else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        logger.log("Face tracking session running", level: .info)
    }

    /// Begin a new face scan. Resets any previous session data.
    func startScanning() {
        guard isARFaceTrackingSupported else {
            logger.log("ARFaceTracking not supported on this device", level: .error)
            scanSession.state = .failed("Cần iPhone X trở lên có Face ID / TrueDepth Camera.")
            return
        }

        scanSession.reset()
        scanSession.state = .scanning
        framesForCurrentDirection = 0
        isCapturingDirection = false
        isCalibrated = false
        directionProgress = 0.0

        if arView != nil {
            runARSession()
        } else {
            logger.log("ARView preparing to attach...", level: .info)
        }
        HapticManager.shared.impact(.medium)
    }

    /// Pause the AR session.
    func stopScanning() {
        arView?.session.pause()
        if scanSession.state == .scanning {
            scanSession.state = .idle
        }
        logger.log("Face tracking session paused", level: .info)
    }

    /// Reset the session and stop AR tracking.
    func resetScan() {
        arView?.session.pause()
        scanSession.reset()
        framesForCurrentDirection = 0
        isCapturingDirection = false
        isCalibrated = false
        directionProgress = 0.0
        logger.log("Scan reset", level: .info)
    }

    /// Called directly on the AR rendering thread.
    /// Uses SIMD math for 0-allocation angle extraction and throttles UI updates.
    func handleFaceAnchorUpdate(_ faceAnchor: ARFaceAnchor) {
        guard faceAnchor.isTracked else {
            let now = CACurrentMediaTime()
            if now - lastUIUpdateTime > uiUpdateInterval {
                lastUIUpdateTime = now
                DispatchQueue.main.async { [weak self] in
                    self?.isFaceDetected = false
                }
            }
            return
        }

        // Fast SIMD Euler angle extraction from 4x4 transform
        let transform = faceAnchor.transform
        let pitch = asin(-transform.columns.2.y)
        let yaw = atan2(transform.columns.2.x, transform.columns.2.z)

        guard scanSession.state == .scanning else { return }

        // Calibrate baseline when looking straight ahead
        if !isCalibrated {
            baseYaw = yaw
            basePitch = pitch
            isCalibrated = true
            logger.log(String(format: "Calibrated baseline: yaw=%.2f, pitch=%.2f", baseYaw, basePitch), level: .debug)
        }

        let relativeYaw = yaw - baseYaw
        let relativePitch = pitch - basePitch
        let direction = scanSession.currentDirection

        // Check if head pose matches target direction
        if direction.isInPosition(relativeYaw: relativeYaw, relativePitch: relativePitch) {
            framesForCurrentDirection += 1

            let progressFraction = min(1.0, Double(framesForCurrentDirection) / Double(requiredFramesPerDirection))

            if framesForCurrentDirection >= requiredFramesPerDirection && !isCapturingDirection {
                isCapturingDirection = true
                captureGeometry(from: faceAnchor.geometry, direction: direction)
            } else {
                // Throttled UI progress update
                let now = CACurrentMediaTime()
                if now - lastUIUpdateTime > uiUpdateInterval {
                    lastUIUpdateTime = now
                    DispatchQueue.main.async { [weak self] in
                        self?.isFaceDetected = true
                        self?.currentYaw = relativeYaw
                        self?.currentPitch = relativePitch
                        self?.directionProgress = progressFraction
                    }
                }
            }
        } else {
            if framesForCurrentDirection > 0 && !isCapturingDirection {
                framesForCurrentDirection = max(0, framesForCurrentDirection - 1)
            }

            let now = CACurrentMediaTime()
            if now - lastUIUpdateTime > uiUpdateInterval {
                lastUIUpdateTime = now
                let progressFraction = min(1.0, Double(framesForCurrentDirection) / Double(requiredFramesPerDirection))
                DispatchQueue.main.async { [weak self] in
                    self?.isFaceDetected = true
                    self?.currentYaw = relativeYaw
                    self?.currentPitch = relativePitch
                    self?.directionProgress = progressFraction
                }
            }
        }
    }

    /// Manual capture button action: captures the current face geometry instantly.
    func manualCaptureCurrentFrame() {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame,
              let faceAnchor = currentFrame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            logger.log("Không tìm thấy khuôn mặt để chụp thủ công", level: .warning)
            HapticManager.shared.notification(.error)
            return
        }

        let direction = scanSession.currentDirection
        captureGeometry(from: faceAnchor.geometry, direction: direction)
        HapticManager.shared.impact(.heavy)
    }

    /// Finish scanning early and start 3D processing with whatever frames were captured.
    func finishScanEarly() {
        guard !scanSession.capturedFrames.isEmpty else {
            logger.log("Chưa có frame nào được chụp", level: .warning)
            return
        }
        processScan()
    }

    /// Capture geometry data from the ARFaceGeometry.
    private func captureGeometry(from geometry: ARFaceGeometry, direction: ScanDirection) {
        let vertices = geometry.vertices
        let texCoords = geometry.textureCoordinates
        let indices = geometry.triangleIndices
        let vertexCount = vertices.count

        let frame = CapturedFrame(
            vertices: vertices,
            textureCoordinates: texCoords,
            triangleIndices: indices,
            direction: direction,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.scanSession.addFrame(frame)
            self.framesForCurrentDirection = 0
            self.directionProgress = 0.0
            self.isCapturingDirection = false

            self.logger.log(
                "Đã quét thành công: \(direction.instruction) (\(vertexCount) vertices)",
                level: .info
            )

            HapticManager.shared.notification(.success)

            // Check if all 5 directions have been completed
            if self.scanSession.isAllDirectionsCaptured {
                self.logger.log("Đã hoàn thành 5/5 góc quét. Bắt đầu xử lý 3D...", level: .info)
                self.processScan()
            }
        }
    }

    /// Process all captured frames into a final merged mesh on a background thread.
    func processScan() {
        scanSession.state = .processing
        arView?.session.pause()
        logger.log("Bắt đầu ghép Mesh 3D đa luồng...", level: .info)

        Task {
            let result = await FaceMeshProcessor.processCapturedFrames(scanSession.capturedFrames)

            await MainActor.run {
                scanSession.finalVertices = result.vertices
                scanSession.finalNormals = result.normals
                scanSession.finalTexCoords = result.texCoords
                scanSession.finalIndices = result.indices

                if result.vertices.isEmpty {
                    scanSession.state = .failed("Không có dữ liệu 3D sau khi xử lý.")
                    logger.log("Ghép mesh thất bại: kết quả rỗng", level: .error)
                    HapticManager.shared.notification(.error)
                } else {
                    scanSession.state = .completed
                    logger.log("Ghép mesh 3D thành công: \(result.vertices.count) đỉnh", level: .info)
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
}
