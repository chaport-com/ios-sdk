import Foundation

struct ChaportLogger {
    // Current minimum log level (default: warning)
    private static var minimumLevel: ChaportLogLevel = .warning

    /// Set the minimum log level
    public static func setLogLevel(_ level: ChaportLogLevel) {
        minimumLevel = level
    }

    /// Log a message at a specific level
    public static func log(_ message: String, level: ChaportLogLevel) {
        guard level >= minimumLevel else { return }
        print("Chaport SDK (\(level.description)): \(message)")
    }
}
