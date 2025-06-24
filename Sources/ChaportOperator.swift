public struct ChaportOperator {
    let id: String?
    let name: String?
    let image: String?
    let colorId: Int?
    let isBot: Bool?

    init?(from raw: Any) {
        guard let dict = raw as? [String: Any] else {
            return nil
        }

        self.id = dict["id"] as? String
        self.name = dict["name"] as? String
        self.image = dict["image"] as? String
        self.colorId = dict["colorId"] as? Int
        self.isBot = dict["isBot"] as? Bool
    }
}
