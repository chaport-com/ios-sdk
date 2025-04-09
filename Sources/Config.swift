import Foundation

public struct Config {
    public let appId: String
    public let session: [String: Any]
    public let region: String?
    
    public init(appId: String, session: [String: Any], region: String? = nil) {
        self.appId = appId
        self.session = session
        self.region = region
    }
}
