import Foundation
import UIKit

/// ViewModel for the Developer/Debug tab.
/// Exposes the shared LoggerService and provides clipboard and clear actions.
final class DeveloperViewModel: ObservableObject {
    let logger = LoggerService.shared

    /// Copy all log entries to the system clipboard and provide haptic feedback.
    func copyLogs() {
        let text = logger.copyAllLogs()
        UIPasteboard.general.string = text
        HapticManager.shared.notification(.success)
        logger.log("Logs copied to clipboard (\(logger.entries.count) entries)", level: .info)
    }

    /// Clear all stored log entries.
    func clearLogs() {
        logger.clearLogs()
        HapticManager.shared.impact(.light)
    }
}
