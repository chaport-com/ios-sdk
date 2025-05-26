import Foundation

struct Logger {
    // Current minimum log level (default: warning)
    @MainActor private static var minimumLevel: LogLevel = .warning

    /// Set the minimum log level
    @MainActor public static func setLogLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    /// Log a message at a specific level
    @MainActor public static func log(_ message: String, level: LogLevel) {
        guard level >= minimumLevel else { return }
        print("\(level.description): \(message)")
    }
}
