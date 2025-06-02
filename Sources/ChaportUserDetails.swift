import Foundation

public struct ChaportUserDetails {
    public let id: String
    public let token: String
    
    public init(id: String, token: String) {
        self.id = id
        self.token = token
    }
}
