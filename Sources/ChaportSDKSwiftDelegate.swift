import Foundation

public protocol ChaportSDKSwiftDelegate: NSObjectProtocol {
    func unreadMessageDidChange(unreadInfo: ChaportUnreadMessageInfo)
}

extension ChaportSDKSwiftDelegate {
    func unreadMessageDidChange(unreadInfo: ChaportUnreadMessageInfo) {
        // default no-op
    }
}
