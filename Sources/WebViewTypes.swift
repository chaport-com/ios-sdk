import Foundation

//enum WebViewAction: String {
//    case getUnreadMessage
//    case canStartBot
//}

enum WebViewResult {
    case getUnreadMessage(UnreadMessage)
    case canStartBot(Bool)
    case any(Any)
}

struct WebViewMessage {
    let action: String
    let payload: Any
    let requestId: String?
}

@objc public enum WebViewLinkAction: Int {
    case allow
    case cancel
}
