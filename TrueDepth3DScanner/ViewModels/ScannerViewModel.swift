import Foundation
import ARKit
import SceneKit
import Combine
import simd

/// Manages the face scanning lifecycle:
/// - Smooth 60 FPS SIMD face orientation extraction
/// - Steady multi-frame accumulation (14 frames per angle) for smooth, natural scanning all around the face
/// - Real-time percentage progress tracking for 3D processing (0% -> 100%)
/// - Interactive tap-to-select direction & Manual shutter capture
final class ScannerViewModel: NSObject, ObservableObject {

    @Published var scanSession = FaceScanSession()
    @Published var isFaceDetected: Bool = false
    @Published var currentDeltaX: Float = 0.0
    @Published var currentDeltaY: Float = 0.0
    @Published var directionProgress: Double = 0.0

    // 3D Processing Progress
    @Published var processingProgress: Double = 0.0
    @Published var processingStage: String = "Đang phân tích cấu trúc 3D..."

    private let logger = LoggerService.shared
    private var framesForCurrentDirection: Int = 0
    private let requiredFramesPerDirection: Int = 14  // ~0.4s smooth deliberate hold/turn for high-density scanning
    private var isCapturingDirection: Bool = false
    private weak var arView: ARSCNView?

    // Baseline face orientation (calibrated on center)
    private var baselineX: Float = 0.0
    private var baselineY: Float = 0.0
    private var isCalibrated: Bool = false

    // UI Throttling
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.066 // ~15 FPS UI update

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
        processingProgress = 0.0
        processingStage = "Đang phân tích cấu trúc 3D..."

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
        processingProgress = 0.0
        logger.log("Scan reset", level: .info)
    }

    /// Manually switch the active target direction when user taps a direction in the checklist.
    func selectDirection(_ direction: ScanDirection) {
        scanSession.currentDirection = direction
        framesForCurrentDirection = 0
        directionProgress = 0.0
        HapticManager.shared.selection()
    }

    /// Called directly on the AR rendering thread.
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

        // Extract face normal vector (columns.2)
        let transform = faceAnchor.transform
        let currentX = transform.columns.2.x
        let currentY = transform.columns.2.y

        guard scanSession.state == .scanning else { return }

        // Calibrate baseline when looking straight ahead
        if !isCalibrated {
            baselineX = currentX
            baselineY = currentY
            isCalibrated = true
            logger.log(String(format: "Calibrated baseline: x=%.3f, y=%.3f", baselineX, baselineY), level: .debug)
        }

        let deltaX = currentX - baselineX
        let deltaY = currentY - baselineY
        let direction = scanSession.currentDirection

        // Check if head pose matches target direction
        let matched = direction.isMatched(deltaX: deltaX, deltaY: deltaY)

        if matched {
            framesForCurrentDirection += 1

            let progressFraction = min(1.0, Double(framesForCurrentDirection) / Double(requiredFramesPerDirection))

            if framesForCurrentDirection >= requiredFramesPerDirection && !isCapturingDirection {
                isCapturingDirection = true
                captureGeometry(from: faceAnchor.geometry, direction: direction)
            } else {
                let now = CACurrentMediaTime()
                if now - lastUIUpdateTime > uiUpdateInterval {
                    lastUIUpdateTime = now
                    DispatchQueue.main.async { [weak self] in
                        self?.isFaceDetected = true
                        self?.currentDeltaX = deltaX
                        self?.currentDeltaY = deltaY
                        self?.directionProgress = progressFraction
                    }
                }
            }
        } else {
            // Gradually decay if head turns away
            if framesForCurrentDirection > 0 && !isCapturingDirection {
                framesForCurrentDirection = max(0, framesForCurrentDirection - 1)
            }

            let now = CACurrentMediaTime()
            if now - lastUIUpdateTime > uiUpdateInterval {
                lastUIUpdateTime = now
                let progressFraction = min(1.0, Double(framesForCurrentDirection) / Double(requiredFramesPerDirection))
                DispatchQueue.main.async { [weak self] in
                    self?.isFaceDetected = true
                    self?.currentDeltaX = deltaX
                    self?.currentDeltaY = deltaY
                    self?.directionProgress = progressFraction
                }
            }
        }
    }

    /// Manual capture button: captures the current face geometry immediately.
    func manualCaptureCurrentFrame() {
        guard let arView = arView,
              let currentFrame = arView.session.currentFrame,
              let faceAnchor = currentFrame.anchors.compactMap({ $0 as? ARFaceAnchor }).first else {
            logger.log("Không tìm thấy khuôn mặt để chụp", level: .warning)
            HapticManager.shared.notification(.error)
            return
        }

        let direction = scanSession.currentDirection
        captureGeometry(from: faceAnchor.geometry, direction: direction)
        HapticManager.shared.impact(.heavy)
    }

    /// Finish scanning early and start 3D processing.
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
                "Đã quét thành công góc: \(direction.instruction) (\(vertexCount) vertices)",
                level: .info
            )

            HapticManager.shared.notification(.success)

            // Auto-advance or finish
            if self.scanSession.isAllDirectionsCaptured {
                self.logger.log("Đã quét đủ 5/5 góc. Đang ghép Mesh 3D...", level: .info)
                self.processScan()
            }
        }
    }

    /// Process all captured frames into a final merged mesh on a background thread with progress feedback.
    func processScan() {
        scanSession.state = .processing
        processingProgress = 0.05
        processingStage = "Đang khởi tạo dữ liệu điểm 3D..."
        arView?.session.pause()
        logger.log("Bắt đầu xử lý dữ liệu 3D...", level: .info)

        Task {
            let result = await FaceMeshProcessor.processCapturedFrames(scanSession.capturedFrames) { [weak self] progress, stage in
                Task { @MainActor in
                    self?.processingProgress = progress
                    self?.processingStage = stage
                }
            }

            await MainActor.run {
                scanSession.finalVertices = result.vertices
                scanSession.finalNormals = result.normals
                scanSession.finalTexCoords = result.texCoords
                scanSession.finalIndices = result.indices

                if result.vertices.isEmpty {
                    scanSession.state = .failed("Không tạo được mô hình 3D.")
                    logger.log("Ghép mesh thất bại", level: .error)
                    HapticManager.shared.notification(.error)
                } else {
                    scanSession.state = .completed
                    logger.log("Mô hình 3D hoàn tất: \(result.vertices.count) đỉnh", level: .info)
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
}
