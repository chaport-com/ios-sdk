import SwiftUI
import ChaportSDK

class ChatWindow {
    
    @MainActor static func setup(with delegate: Delegate) {
        let config = Config(appId: "67ebdc851e966982eb469d50", session: ["persist": true], region: "ru")
        Chaport.shared.delegate = delegate
        Chaport.shared.configure(config: config)
        Chaport.shared.setLanguage(languageCode: "ru")
        Chaport.shared.startSession(details: UserDetails(id: "11111", token: "1345434234"))
        Chaport.shared.setVisitorData(visitor: VisitorData(name: "Test", email: "local@email.ru", phone: "+79992223344", notes: "Notes", custom: ["field1": "Test"]))
    }
 
    class Delegate: NSObject, ChaportSDKDelegate {
        var onSetUnread: ((Int) -> Void)?
        
        func canStartBot(isStart: Bool) {
            print("Can Start bot: \(isStart)")
        }
        
        func chatDidStart() {
            print("Chat did start")
        }
        
        func chatDidPresent() {
            print("Chat did present")
        }
        
        func chatDidDismiss() {
            print("Chat did dismis")
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
