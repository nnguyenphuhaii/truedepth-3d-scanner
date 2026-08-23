import Foundation
import ARKit
import SceneKit
import Combine

/// Manages the full face scanning lifecycle: session control, head-pose detection,
/// per-direction geometry capture, and mesh processing pipeline.
final class ScannerViewModel: NSObject, ObservableObject {

    @Published var scanSession = FaceScanSession()
    @Published var isFaceDetected: Bool = false
    @Published var currentYaw: Float = 0.0
    @Published var currentPitch: Float = 0.0

    private let logger = LoggerService.shared
    private var framesForCurrentDirection: Int = 0
    private let requiredFramesPerDirection: Int = 12
    private var isCapturingDirection: Bool = false
    private weak var arView: ARSCNView?

    /// Whether the device supports ARKit face tracking (TrueDepth camera required).
    var isARFaceTrackingSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Store a weak reference to the ARSCNView for session management.
    func setARView(_ view: ARSCNView) {
        self.arView = view
    }

    /// Begin a new face scan. Resets any previous session data.
    func startScanning() {
        guard isARFaceTrackingSupported else {
            logger.log("ARFaceTracking not supported on this device", level: .error)
            scanSession.state = .failed("Face tracking requires iPhone X or later with TrueDepth camera.")
            return
        }

        guard let arView = arView else {
            logger.log("ARView not available", level: .error)
            return
        }

        scanSession.reset()
        scanSession.state = .scanning
        framesForCurrentDirection = 0
        isCapturingDirection = false

        let configuration = ARFaceTrackingConfiguration()
        configuration.maximumNumberOfTrackedFaces = 1

        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        logger.log("Face tracking session started", level: .info)
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
        logger.log("Scan reset", level: .info)
    }

    /// Called from the ARSCNViewDelegate when a face anchor is updated.
    /// Extracts euler angles and captures geometry when the user is in position.
    func handleFaceAnchorUpdate(_ faceAnchor: ARFaceAnchor) {
        // Extract euler angles via a temporary SCNNode
        let tempNode = SCNNode()
        tempNode.simdTransform = faceAnchor.transform
        let yaw = tempNode.eulerAngles.y
        let pitch = tempNode.eulerAngles.x

        DispatchQueue.main.async { [weak self] in
            self?.isFaceDetected = faceAnchor.isTracked
            self?.currentYaw = yaw
            self?.currentPitch = pitch
        }

        guard scanSession.state == .scanning, faceAnchor.isTracked else { return }

        let direction = scanSession.currentDirection

        // Check if user's head is in the correct position for current direction
        if direction.isInPosition(yaw: yaw, pitch: pitch) {
            framesForCurrentDirection += 1

            if framesForCurrentDirection >= requiredFramesPerDirection && !isCapturingDirection {
                isCapturingDirection = true
                captureGeometry(from: faceAnchor.geometry, direction: direction)
            }
        } else {
            // Reset frame count if user moves out of position
            if framesForCurrentDirection > 0 && !isCapturingDirection {
                framesForCurrentDirection = max(0, framesForCurrentDirection - 2)
            }
        }
    }

    /// Capture the geometry data from the current ARFaceGeometry for a given direction.
    private func captureGeometry(from geometry: ARFaceGeometry, direction: ScanDirection) {
        let vertexCount = geometry.vertexCount
        let indexCount = geometry.triangleCount * 3

        // Copy geometry data using subscript access (compatible with all Swift/Xcode versions)
        let vertexPtr = geometry.vertices
        var vertices = [SIMD3<Float>](repeating: .zero, count: vertexCount)
        for i in 0..<vertexCount { vertices[i] = vertexPtr[i] }

        let texCoordPtr = geometry.textureCoordinates
        var texCoords = [SIMD2<Float>](repeating: .zero, count: vertexCount)
        for i in 0..<vertexCount { texCoords[i] = texCoordPtr[i] }

        let indexPtr = geometry.triangleIndices
        var indices = [Int16](repeating: 0, count: indexCount)
        for i in 0..<indexCount { indices[i] = indexPtr[i] }

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
            self.isCapturingDirection = false

            self.logger.log(
                "Captured direction: \(direction.instruction) "
                + "(\(vertexCount) vertices, \(geometry.triangleCount) triangles)",
                level: .info
            )

            HapticManager.shared.notification(.success)

            // Check if all directions are captured
            if self.scanSession.isAllDirectionsCaptured {
                self.logger.log("All directions captured. Starting processing.", level: .info)
                self.processScan()
            }
        }
    }

    /// Process all captured frames into a final merged mesh on a background thread.
    func processScan() {
        scanSession.state = .processing
        arView?.session.pause()
        logger.log("Mesh processing started", level: .info)

        Task {
            let result = await FaceMeshProcessor.processCapturedFrames(scanSession.capturedFrames)

            await MainActor.run {
                scanSession.finalVertices = result.vertices
                scanSession.finalNormals = result.normals
                scanSession.finalTexCoords = result.texCoords
                scanSession.finalIndices = result.indices

                if result.vertices.isEmpty {
                    scanSession.state = .failed("Processing failed: no mesh data generated.")
                    logger.log("Processing failed: empty result", level: .error)
                } else {
                    scanSession.state = .completed
                    logger.log("Processing complete: \(result.vertices.count) vertices", level: .info)
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }

    /// Fraction of required frames captured for the current direction (0.0 to 1.0).
    var directionProgress: Double {
        Double(framesForCurrentDirection) / Double(requiredFramesPerDirection)
    }
}
