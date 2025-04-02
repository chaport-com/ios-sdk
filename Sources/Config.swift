import Foundation

public struct Config {
    public var appId: String
    public var session: Session?
    
    private var storage: [String: String] = [:]

    public init(appId: String, session: Session? = nil) {
        self.appId = appId
        self.session = session
    }

    public subscript(key: String) -> String? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
}
