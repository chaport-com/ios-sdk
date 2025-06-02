import Foundation

public struct ChaportConfig {
    public var appId: String
    public var session: ChaportSessionConfig?
    
    private var storage: [String: String] = [:]

    public init(appId: String, session: ChaportSessionConfig? = nil) {
        self.appId = appId
        self.session = session
    }

    public subscript(key: String) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
}
