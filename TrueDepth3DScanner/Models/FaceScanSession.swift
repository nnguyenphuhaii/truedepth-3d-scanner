import Foundation
import ARKit
import UIKit

/// A single captured frame of face geometry and camera image from a specific scan direction.
struct CapturedFrame {
    let vertices: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let triangleIndices: [Int16]
    let direction: ScanDirection
    let timestamp: Date
    let cameraImage: UIImage?
}

/// Represents the current state of the scanning pipeline.
enum ScanState: Equatable {
    case idle
    case scanning
    case processing
    case completed
    case failed(String)

    static func == (lhs: ScanState, rhs: ScanState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.scanning, .scanning),
             (.processing, .processing),
             (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Observable model that holds all data for a face scan session.
/// Tracks captured frames per direction, overall progress, and the final merged mesh with photo texture.
class FaceScanSession: ObservableObject {
    @Published var capturedFrames: [CapturedFrame] = []
    @Published var completedDirections: Set<ScanDirection> = []
    @Published var currentDirection: ScanDirection = .center
    @Published var progress: Double = 0.0
    @Published var state: ScanState = .idle

    // Final merged 3D mesh data with real photo texture
    @Published var finalVertices: [SIMD3<Float>] = []
    @Published var finalNormals: [SIMD3<Float>] = []
    @Published var finalTexCoords: [SIMD2<Float>] = []
    @Published var finalIndices: [Int16] = []
    @Published var finalTexture: UIImage?

    /// Add a captured frame and update progress.
    func addFrame(_ frame: CapturedFrame) {
        capturedFrames.append(frame)
        completedDirections.insert(frame.direction)
        progress = Double(completedDirections.count) / Double(ScanDirection.allCases.count)

        if let next = nextDirection {
            currentDirection = next
        }
    }

    /// The next uncaptured direction in guided order, or `nil` if all directions are captured.
    var nextDirection: ScanDirection? {
        ScanDirection.allCases.first { !completedDirections.contains($0) }
    }

    /// Whether all five directions have been captured.
    var isAllDirectionsCaptured: Bool {
        completedDirections.count == ScanDirection.allCases.count
    }

    /// Reset the session to its initial idle state.
    func reset() {
        capturedFrames.removeAll()
        completedDirections.removeAll()
        currentDirection = .center
        progress = 0.0
        state = .idle
        finalVertices.removeAll()
        finalNormals.removeAll()
        finalTexCoords.removeAll()
        finalIndices.removeAll()
        finalTexture = nil
    }
}
