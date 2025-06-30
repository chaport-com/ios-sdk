import Foundation

public struct ChaportUnreadMessageInfo {
    public let count: Int
    public let lastMessageAt: Date?
    public let lastMessageText: String?
    public let lastMessageAuthor: ChaportOperator?
    
    public init(
        count: Int,
        lastMessageText: String?,
        lastMessageAuthor: ChaportOperator?,
        lastMessageAt: Date
    ) {
        self.count = count
        self.lastMessageText = lastMessageText
        self.lastMessageAuthor = lastMessageAuthor
        self.lastMessageAt = lastMessageAt
    }

    init?(from raw: Any) {
        guard let dict = raw as? [String: Any] else {
            return nil
        }

        self.count = dict["count"] as? Int ?? 0
        self.lastMessageText = dict["lastMessageText"] as? String

        if let authorRaw = dict["lastMessageAuthor"] {
            self.lastMessageAuthor = ChaportOperator(from: authorRaw)
        } else {
            self.lastMessageAuthor = nil
        }
        
        if let timestamp = dict["lastMessageAt"] as? TimeInterval {
            self.lastMessageAt = Date(timeIntervalSince1970: timestamp)
        } else {
            self.lastMessageAt = nil
        }
    }
}
