public struct ChaportUnreadMessageInfo {
    let count: Int
    let lastMessage: String?
    let lastMessageAuthor: ChaportOperator?

    init?(from raw: Any) {
        guard let dict = raw as? [String: Any] else {
            return nil
        }

        self.count = dict["count"] as? Int ?? 0
        self.lastMessage = dict["lastMessage"] as? String

        if let authorRaw = dict["lastMessageAuthor"] {
            self.lastMessageAuthor = ChaportOperator(from: authorRaw)
        } else {
            self.lastMessageAuthor = nil
        }
    }
}
