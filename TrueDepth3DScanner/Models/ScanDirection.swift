import Foundation

/// Represents the five directions the user is guided to turn during scanning.
enum ScanDirection: Int, CaseIterable, Identifiable {
    case center = 0
    case left
    case right
    case up
    case down

    var id: Int { rawValue }

    var instruction: String {
        switch self {
        case .center: return "Nhìn Thẳng Vào Camera"
        case .left:   return "Xoay Đầu Sang Trái"
        case .right:  return "Xoay Đầu Sang Phải"
        case .up:     return "Ngửa Đầu Lên Trên"
        case .down:   return "Cúi Đầu Xuống Dưới"
        }
    }

    var hint: String {
        switch self {
        case .center: return "Giữ thẳng khuôn mặt"
        case .left:   return "Nghiêng nhẹ ~15° sang trái"
        case .right:  return "Nghiêng nhẹ ~15° sang phải"
        case .up:     return "Ngước nhẹ ~10° lên trên"
        case .down:   return "Cúi nhẹ ~10° xuống dưới"
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

    /// Check if current head pose (relative to center baseline) matches this target direction.
    /// Uses flexible thresholds in radians (~10-15 degrees) for effortless, natural scanning.
    func isInPosition(relativeYaw: Float, relativePitch: Float) -> Bool {
        switch self {
        case .center:
            return abs(relativeYaw) < 0.22 && abs(relativePitch) < 0.22
        case .left:
            return relativeYaw > 0.18
        case .right:
            return relativeYaw < -0.18
        case .up:
            return relativePitch > 0.14
        case .down:
            return relativePitch < -0.14
        }
    }
}
