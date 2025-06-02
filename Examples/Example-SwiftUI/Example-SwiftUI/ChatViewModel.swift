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
        
        setupSDK()
    }

    private func setupSDK() {
        let config = ChaportConfig(appId: "<appId>")

        ChaportSDK.shared.delegate = self
        ChaportSDK.shared.configure(config: config)
        
        setupVisitor()
    }
    
    private func setupVisitor() {
        ChaportSDK.shared.startSession()
        ChaportSDK.shared.setVisitorData(visitor: ChaportVisitorData(name: "Test SDK visitor"))
    }

    func clearSession() {
        ChaportSDK.shared.stopSession {
            DispatchQueue.main.async {
                self.setupVisitor()
            }
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
        DispatchQueue.main.async {
            self.isChatVisible = true
        }
    }

    nonisolated func chatDidDismiss() {
        DispatchQueue.main.async {
            self.isChatVisible = false
        }
    }

    nonisolated func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
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
        print("Chat failed: \(error.localizedDescription)")
    }

    nonisolated func linkDidClick(url: URL) -> ChaportLinkAction {
        print("Clicked link: \(url)")
        return .allow
    }
}
