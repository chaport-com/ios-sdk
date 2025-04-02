import Foundation

public protocol ChaportSDKDelegate: AnyObject {
    func chatDidStart()
    func chatDidPresent()
    func chatDidDismiss()
    func chatDidFail(error: Error)
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?)
    func linkDidClick(url: URL)
}
