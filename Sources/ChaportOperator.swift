public struct ChaportOperator: Equatable {
    public let id: String?
    public let name: String?
    public let image: String?
    public let colorId: Int?
    public let isBot: Bool?
    
    public static func == (lhs: ChaportOperator, rhs: ChaportOperator) -> Bool {
        guard let leftId = lhs.id, let rightId = rhs.id else {
            // Treat any nil (even both nil) as not equal
            return false
        }
        return leftId == rightId
    }

    init?(from raw: Any) {
        guard let dict = raw as? [String: Any] else {
            return nil
        }

        self.id = dict["id"] as? String
        self.name = dict["name"] as? String
        self.image = dict["image"] as? String
        self.colorId = dict["colorId"] as? Int
        self.isBot = dict["isBot"] as? Bool ?? false
    }
    
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [
            "isBot": isBot ?? false
        ]

        if let id = id { dict["id"] = id }
        if let name = name { dict["name"] = name }
        if let image = image { dict["image"] = image }
        if let colorId = colorId { dict["colorId"] = colorId }
        return dict
    }
}
