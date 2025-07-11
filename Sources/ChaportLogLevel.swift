import Foundation

public enum ChaportLogLevel: Int, Comparable {
    case debug = 0
    case info
    case warning
    case error
    case none

    public var description: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .none: return "NONE";
        }
    }

    public static func < (lhs: ChaportLogLevel, rhs: ChaportLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
