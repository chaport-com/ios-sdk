import Foundation

public struct ChaportUserCredentials {
    public let id: String
    public let token: String
    
    public init(id: String, token: String) {
        self.id = id
        self.token = token
    }
}
