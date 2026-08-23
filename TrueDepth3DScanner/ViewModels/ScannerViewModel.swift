import Foundation
import ARKit
import SceneKit
import Combine
import CoreImage
import UIKit
import simd

/// Manages the face scanning lifecycle:
/// - 60 FPS SIMD face orientation extraction
/// - Exact 1:1 camera projection UV calculation so the photo texture perfectly fits eyes, nose, and lips
/// - Multi-angle accumulation without canonical geometry distortion
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
    private let requiredFramesPerDirection: Int = 12  // Smooth deliberate hold (~0.35s)
    private var isCapturingDirection: Bool = false
    private weak var arView: ARSCNView?
    private var cancellables = Set<AnyCancellable>()
    private let ciContext = CIContext(options: nil)

    // Baseline face orientation (calibrated on center)
    private var baselineX: Float = 0.0
    private var baselineY: Float = 0.0
    private var isCalibrated: Bool = false

    // UI Throttling
    private var lastUIUpdateTime: TimeInterval = 0
    private let uiUpdateInterval: TimeInterval = 0.066 // ~15 FPS UI update

    override init() {
        super.init()
        // Automatically bubble nested scanSession changes to ViewModel subscribers
        scanSession.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

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
                captureGeometry(from: faceAnchor, direction: direction)
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
        captureGeometry(from: faceAnchor, direction: direction)
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

    /// Extract an upright portrait UIImage from the ARFrame's captured pixel buffer.
    private func extractPortraitCameraImage() -> (image: UIImage?, size: CGSize) {
        guard let pixelBuffer = arView?.session.currentFrame?.capturedImage else { return (nil, .zero) }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let orientedCIImage = ciImage.oriented(.right)

        guard let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return (nil, .zero) }
        let portraitImage = UIImage(cgImage: cgImage)
        let portraitSize = orientedCIImage.extent.size

        return (portraitImage, portraitSize)
    }

    /// Compute precise 2D projective UV coordinates mapping each 3D vertex onto the camera photo.
    private func computeProjectiveUVs(
        vertices: [SIMD3<Float>],
        faceTransform: simd_float4x4,
        camera: ARCamera,
        viewportSize: CGSize
    ) -> [SIMD2<Float>] {
        var uvs = [SIMD2<Float>]()
        uvs.reserveCapacity(vertices.count)

        for v in vertices {
            // Local face coordinate to world/camera space
            let localPoint = simd_float4(v.x, v.y, v.z, 1.0)
            let worldPoint4 = simd_mul(faceTransform, localPoint)
            let worldPoint = simd_float3(worldPoint4.x, worldPoint4.y, worldPoint4.z)

            // Project onto portrait camera viewport
            let projected = camera.projectPoint(
                worldPoint,
                orientation: .portrait,
                viewportSize: viewportSize
            )

            let u = Float(projected.x / viewportSize.width)
            let v = Float(projected.y / viewportSize.height)

            uvs.append(SIMD2<Float>(max(0.0, min(1.0, u)), max(0.0, min(1.0, v))))
        }

        return uvs
    }

    /// Capture geometry data and camera photo from the ARFaceAnchor with camera projection UVs.
    private func captureGeometry(from faceAnchor: ARFaceAnchor, direction: ScanDirection) {
        let geometry = faceAnchor.geometry
        let vertices = geometry.vertices
        let canonicalUVs = geometry.textureCoordinates
        let indices = geometry.triangleIndices
        let vertexCount = vertices.count

        let (cameraPhoto, photoSize) = extractPortraitCameraImage()

        // Calculate exact projective UVs if camera is available
        var finalUVs = canonicalUVs
        if let camera = arView?.session.currentFrame?.camera, photoSize.width > 0 {
            finalUVs = computeProjectiveUVs(
                vertices: vertices,
                faceTransform: faceAnchor.transform,
                camera: camera,
                viewportSize: photoSize
            )
        }

        let frame = CapturedFrame(
            vertices: vertices,
            textureCoordinates: finalUVs,
            canonicalUVs: canonicalUVs,
            triangleIndices: indices,
            direction: direction,
            timestamp: Date(),
            cameraImage: cameraPhoto
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.scanSession.addFrame(frame)
            self.framesForCurrentDirection = 0
            self.directionProgress = 0.0
            self.isCapturingDirection = false

            self.logger.log(
                "Đã quét thành công góc: \(direction.instruction) (\(vertexCount) vertices, ảnh: \(cameraPhoto != nil))",
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
        processingStage = "Đang phân tích cấu trúc 3D & trích xuất ảnh mặt thật..."
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
                self.scanSession.finalVertices = result.vertices
                self.scanSession.finalNormals = result.normals
                self.scanSession.finalTexCoords = result.texCoords
                self.scanSession.finalIndices = result.indices
                self.scanSession.finalTexture = result.texture

                if result.vertices.isEmpty {
                    self.scanSession.state = .failed("Không tạo được mô hình 3D.")
                    self.logger.log("Ghép mesh thất bại", level: .error)
                    HapticManager.shared.notification(.error)
                } else {
                    self.scanSession.state = .completed
                    self.logger.log("Mô hình 3D hoàn tất: \(result.vertices.count) đỉnh, Texture ảnh thật: \(result.texture != nil)", level: .info)
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
}
