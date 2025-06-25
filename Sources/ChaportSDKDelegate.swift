import Foundation

@objc public protocol ChaportSDKDelegate: NSObjectProtocol {
    @objc optional func chatDidStart()
    @objc optional func chatDidPresent()
    @objc optional func chatDidDismiss()
    @objc optional func chatDidFail(error: Error)
    @objc optional func unreadMessageDidChange(
        count: Int,
        lastMessageText: String?,
        lastMessageAuthor: NSDictionary?,
        lastMessageAt: Date?
    )
    @objc optional func linkDidClick(url: URL) -> ChaportLinkAction
}
