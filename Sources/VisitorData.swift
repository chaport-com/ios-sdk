import Foundation

public struct VisitorData {
    public let name: String
    public let email: String
    public let custom: [String: Any]
    
    public init(name: String, email: String, custom: [String: Any]) {
        self.name = name
        self.email = email
        self.custom = custom
    }
}
