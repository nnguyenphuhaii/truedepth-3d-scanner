import UIKit

/// Thin wrapper around UIKit feedback generators for haptic feedback.
/// Provides notification, impact, and selection feedback via a shared singleton.
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Trigger a notification haptic (success, warning, or error).
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    /// Trigger an impact haptic with the specified style intensity.
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Trigger a light selection-change haptic.
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
