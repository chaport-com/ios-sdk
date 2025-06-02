import Foundation

struct ChaportLogger {
    // Current minimum log level (default: warning)
    @MainActor private static var minimumLevel: ChaportLogLevel = .warning

    /// Set the minimum log level
    @MainActor public static func setLogLevel(_ level: ChaportLogLevel) {
        minimumLevel = level
    }

    /// Log a message at a specific level
    @MainActor public static func log(_ message: String, level: ChaportLogLevel) {
        guard level >= minimumLevel else { return }
        print("Chaport SDK (\(level.description)): \(message)")
    }
}
