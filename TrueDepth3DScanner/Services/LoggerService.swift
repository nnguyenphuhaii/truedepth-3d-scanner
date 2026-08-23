import Foundation
import Combine

/// Severity level for log entries.
enum LogLevel: String, CaseIterable {
    case info    = "INFO"
    case warning = "WARN"
    case error   = "ERROR"
    case debug   = "DEBUG"
}

/// A single timestamped log entry.
struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    /// Formatted string representation for display and clipboard export.
    var formatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] [\(level.rawValue)] \(message)"
    }
}

/// Centralized, thread-safe logging service.
/// Captures ARSession errors, runtime messages, and custom logs.
/// Displayed in the Developer tab for debugging.
final class LoggerService: ObservableObject {
    static let shared = LoggerService()

    @Published private(set) var entries: [LogEntry] = []

    private let queue = DispatchQueue(label: "com.truedepth.logger", qos: .utility)

    private init() {
        log("LoggerService initialized", level: .info)
        log("Device: \(deviceInfo())", level: .info)
    }

    /// Append a log entry. Safe to call from any thread.
    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)
        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.entries.append(entry)
            }
        }
        #if DEBUG
        print(entry.formatted)
        #endif
    }

    /// Returns all logs as a single string, suitable for clipboard copy.
    func copyAllLogs() -> String {
        entries.map { $0.formatted }.joined(separator: "\n")
    }

    /// Remove all stored log entries.
    func clearLogs() {
        DispatchQueue.main.async { [weak self] in
            self?.entries.removeAll()
            self?.log("Logs cleared", level: .info)
        }
    }

    /// Collects basic device information for diagnostic logs.
    private func deviceInfo() -> String {
        let device = ProcessInfo.processInfo
        return "\(device.operatingSystemVersionString) | Processors: \(device.processorCount)"
    }
}
