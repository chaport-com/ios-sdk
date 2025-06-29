import SwiftUI
import Chaport

@MainActor
class ChatViewModel: NSObject, ObservableObject {
    @Published var isChatVisible: Bool = ChaportSDK.shared.isChatVisible()
    @Published var unreadCount: Int = 0
    
    weak var embedController: UIViewController?
    weak var chatContainer: UIView?

    override init() {
        super.init()
        
        setup()
    }

    private func setup() {
        let config = ChaportConfig(appId: "<appId>")

        ChaportSDK.shared.setDelegate(self)
        ChaportSDK.shared.configure(with: config)
        
        setupVisitor()
    }
    
    private func setupVisitor() {
        ChaportSDK.shared.startSession()
        ChaportSDK.shared.setVisitorData(ChaportVisitorData(name: "Test SDK visitor"))
    }

    func clearSession() {
        ChaportSDK.shared.stopSession {
            self.setupVisitor()
        }
    }

    func presentChat() {
        ChaportSDK.shared.present()
    }

    func embedChat() {
        guard let vc = embedController,
              let container = chatContainer else {
            return
        }
        ChaportSDK.shared.embed(into: container, parentViewController: vc)
    }

    func openFAQ() {
        embedChat()
        ChaportSDK.shared.openFAQ()
    }

    func removeChat() {
        ChaportSDK.shared.remove()
    }
}

extension ChatViewModel: ChaportSDKDelegate {
    nonisolated func chatDidPresent() {
        print("Chat presented")
        DispatchQueue.main.async {
            self.isChatVisible = true
        }
    }

    nonisolated func chatDidDismiss() {
        print("Chat dismissed")
        DispatchQueue.main.async {
            self.isChatVisible = false
        }
    }

    nonisolated func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
        print("Unread message changed: unreadCount: \(unreadCount), lastMessage: \(lastMessage ?? "")")
        DispatchQueue.main.async {
            self.unreadCount = unreadCount
        }
    }

    nonisolated func chatDidStart() {
        print("Chat started")
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("Push permission denied: \(String(describing: error))")
            }
        }
    }

    nonisolated func chatDidFail(error: Error) {
        print("Chat error: \(error)")
    }

    nonisolated func linkDidClick(url: URL) -> ChaportLinkAction {
        print("Link clicked: \(url)")
        return .allow
    }
}
