import Foundation

public struct ChaportPushOperator: Codable {
    public let id: String
    public let name: String
    public let image: String
}

public struct ChaportPushPayload: Codable {
    public let `operator`: ChaportPushOperator
    public let message: String?
}
