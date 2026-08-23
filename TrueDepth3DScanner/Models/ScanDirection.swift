import Foundation

/// Represents the five directions the user must face during scanning.
/// Each direction defines yaw/pitch thresholds used to detect correct head orientation.
enum ScanDirection: Int, CaseIterable, Identifiable {
    case center = 0
    case left
    case right
    case up
    case down

    var id: Int { rawValue }

    var instruction: String {
        switch self {
        case .center: return "Look Straight Ahead"
        case .left:   return "Slowly Turn Left"
        case .right:  return "Slowly Turn Right"
        case .up:     return "Slowly Look Up"
        case .down:   return "Slowly Look Down"
        }
    }

    var systemImage: String {
        switch self {
        case .center: return "face.smiling"
        case .left:   return "arrow.left"
        case .right:  return "arrow.right"
        case .up:     return "arrow.up"
        case .down:   return "arrow.down"
        }
    }

    /// Target yaw angle in radians for this direction.
    var yawTarget: Float {
        switch self {
        case .center:           return  0.0
        case .left:             return  0.45
        case .right:            return -0.45
        case .up, .down:        return  0.0
        }
    }

    /// Target pitch angle in radians for this direction.
    var pitchTarget: Float {
        switch self {
        case .center:            return  0.0
        case .left, .right:      return  0.0
        case .up:                return  0.3
        case .down:              return -0.3
        }
    }

    /// Returns `true` when the measured yaw and pitch are within tolerance of this direction's targets.
    func isInPosition(yaw: Float, pitch: Float) -> Bool {
        let yawTolerance: Float = 0.18
        let pitchTolerance: Float = 0.18
        return abs(yaw - yawTarget) < yawTolerance && abs(pitch - pitchTarget) < pitchTolerance
    }
}
