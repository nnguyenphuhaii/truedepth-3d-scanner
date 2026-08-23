import Foundation

/// Represents the five guided directions for face scanning.
enum ScanDirection: Int, CaseIterable, Identifiable {
    case center = 0
    case left
    case right
    case up
    case down

    var id: Int { rawValue }

    var instruction: String {
        switch self {
        case .center: return "Nhìn Thẳng"
        case .left:   return "Xoay Sang Trái"
        case .right:  return "Xoay Sang Phải"
        case .up:     return "Ngước Lên Trên"
        case .down:   return "Cúi Xuống Dưới"
        }
    }

    var hint: String {
        switch self {
        case .center: return "Giữ mặt ở giữa khung hình"
        case .left:   return "Xoay nhẹ mặt sang trái"
        case .right:  return "Xoay nhẹ mặt sang phải"
        case .up:     return "Ngước nhẹ cằm lên trên"
        case .down:   return "Cúi nhẹ cằm xuống dưới"
        }
    }

    var systemImage: String {
        switch self {
        case .center: return "face.smiling.fill"
        case .left:   return "arrow.left.circle.fill"
        case .right:  return "arrow.right.circle.fill"
        case .up:     return "arrow.up.circle.fill"
        case .down:   return "arrow.down.circle.fill"
        }
    }

    /// Checks if current normal vector delta matches target direction.
    /// deltaX: horizontal face orientation relative to center baseline.
    /// deltaY: vertical face orientation relative to center baseline.
    func isMatched(deltaX: Float, deltaY: Float) -> Bool {
        let hThreshold: Float = 0.07 // ~4-5 degrees
        let vThreshold: Float = 0.06 // ~3-4 degrees (extremely easy to reach)

        switch self {
        case .center:
            return abs(deltaX) < 0.12 && abs(deltaY) < 0.12
        case .left:
            return deltaX > hThreshold || deltaX < -hThreshold && abs(deltaX) > abs(deltaY) * 1.2
        case .right:
            return deltaX < -hThreshold || deltaX > hThreshold && abs(deltaX) > abs(deltaY) * 1.2
        case .up:
            // When looking UP, deltaY > 0 or deltaY < 0 depending on matrix projection
            // Checking both absolute dominant vertical movement and direct sign
            return deltaY > vThreshold || (abs(deltaY) > vThreshold && abs(deltaY) > abs(deltaX))
        case .down:
            return deltaY < -vThreshold || (abs(deltaY) > vThreshold && abs(deltaY) > abs(deltaX))
        }
    }
}
