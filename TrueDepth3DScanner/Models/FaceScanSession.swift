import Foundation
import ARKit

/// A single captured frame of face geometry from a specific scan direction.
struct CapturedFrame {
    let vertices: [SIMD3<Float>]
    let textureCoordinates: [SIMD2<Float>]
    let triangleIndices: [Int16]
    let direction: ScanDirection
    let timestamp: Date
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
/// Tracks captured frames per direction, overall progress, and the final merged mesh.
class FaceScanSession: ObservableObject {
    @Published var capturedFrames: [CapturedFrame] = []
    @Published var completedDirections: Set<ScanDirection> = []
    @Published var currentDirection: ScanDirection = .center
    @Published var progress: Double = 0.0
    @Published var state: ScanState = .idle

    // Final merged mesh data (populated after processing)
    @Published var finalVertices: [SIMD3<Float>] = []
    @Published var finalNormals: [SIMD3<Float>] = []
    @Published var finalTexCoords: [SIMD2<Float>] = []
    @Published var finalIndices: [Int16] = []

    /// Add a captured frame and update progress.
    func addFrame(_ frame: CapturedFrame) {
        capturedFrames.append(frame)
        completedDirections.insert(frame.direction)
        progress = Double(completedDirections.count) / Double(ScanDirection.allCases.count)

        if let next = nextDirection {
            currentDirection = next
        }
    }

    /// Reset all session data to initial state.
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
    }

    /// Returns the next direction that has not yet been captured, or `nil` if all are done.
    var nextDirection: ScanDirection? {
        ScanDirection.allCases.first { !completedDirections.contains($0) }
    }

    /// Returns `true` when all five directions have been captured.
    var isAllDirectionsCaptured: Bool {
        completedDirections.count == ScanDirection.allCases.count
    }
}
