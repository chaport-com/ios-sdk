import SwiftUI
import Chaport

class ChatWindow {
    
    @MainActor static func setup(with delegate: Delegate) {
        var config = Config(appId: "68053332ad398e9f37c63675")
        config["region"] = "eu"
        ChaportSDK.shared.delegate = delegate
        ChaportSDK.shared.configure(config: config)
        ChaportSDK.shared.setVisitorData(visitor: VisitorData(name: "Test SDK visitor"))
        ChaportSDK.shared.startSession()
    }
 
    class Delegate: NSObject, ChaportSDKDelegate {
        var onSetUnread: ((Int) -> Void)?
        var onSetStart: ((Bool) -> Void)?
        
        func chatDidStart() {
            print("Chat did start")
        }
        
        func chatDidPresent() {
            print("Chat did present")
            
            if onSetStart != nil {
                onSetStart!(true)
            }
        }
        
        func chatDidDismiss() {
            print("Chat did dismis")
            
            if onSetStart != nil {
                onSetStart!(false)
            }
        }
        
        func chatDidFail(error: any Error) {
            print("Chat did fail: \(error)")
        }
        
        func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
            if onSetUnread != nil {
                onSetUnread!(unreadCount)
            }
            
            print("Chat unreadMessageDidChange, unreadCount: \(unreadCount), lastMessage: \(lastMessage ?? "")")
        }
        
        func linkDidClick(url: URL) {
            print("Chat did click link: \(url)")
        }
    }
}
