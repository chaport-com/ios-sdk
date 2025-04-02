import Foundation

public struct VisitorData {
    public let name: String?
    public let email: String?
    public let phone: String?
    public let notes: String?
    public let custom: [String: Any]?
    
    public init(
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        notes: String? = nil,
        custom: [String: Any]? = nil
    ) {
        self.name = name
        self.email = email
        self.phone = phone
        self.notes = notes
        self.custom = custom
    }
}

extension VisitorData {
    var asDictionary: [String: Any] {
        var dict: [String: Any] = [:]
        if let name = name {
            dict["name"] = name
        }
        if let email = email {
            dict["email"] = email
        }
        if let phone = phone {
            dict["phone"] = phone
        }
        if let notes = notes {
            dict["notes"] = notes
        }
        if let custom = custom {
            dict["custom"] = custom
        }
        return dict
    }
}
