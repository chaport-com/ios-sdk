import UIKit
import Chaport

class ViewController: UIViewController {
    
    @IBOutlet weak var chat: UIView!
    @IBOutlet weak var unreadButton: UIButton!
    @IBOutlet weak var removeButton: UIButton!
    
    var unread: Int = 0 {
        didSet {
            updateUnreadLabel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        removeButton.tintColor =  UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)
        unreadButton.tintColor = UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)
        setup()
    }
    
    @IBAction func openChatModal(_ sender: UIButton) {
        ChaportSDK.shared.present(from: self)
    }
    
    @IBAction func openChatEmbed(_ sender: UIButton) {
        ChaportSDK.shared.embed(into: chat, parentViewController: self)
    }
    
    @IBAction func clearSession(_ sender: UIButton) {
        ChaportSDK.shared.stopSession() {
            self.setupVisitor()
        }
    }
    
    @IBAction func openFAQ(_ sender: UIButton) {
        ChaportSDK.shared.embed(into: chat, parentViewController: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            ChaportSDK.shared.openFAQ()
        }
    }
    
    @IBAction func remove(_ sender: UIButton) {
        ChaportSDK.shared.remove()
    }
    
    private func setup() {
        ChaportSDK.shared.setDelegate(self)
        ChaportSDK.shared.configure(with: ChaportConfig(appId: "<appId>"))
        
        setupVisitor()
    }
    
    private func setupVisitor() {
        ChaportSDK.shared.startSession()
        ChaportSDK.shared.setVisitorData(ChaportVisitorData(name: "Test SDK visitor"))
        
        ChaportSDK.shared.fetchUnreadMessageInfo() { result in
            switch result {
            case .success(let unreadInfo):
                DispatchQueue.main.async {
                    self.unread = unreadInfo.count
                    self.updateUnreadLabel()
                }
            case .failure(let error):
                self.chatDidFail(error: error)
            }
        }
    }
    
    private func updateUnreadLabel() {
        let title = "Unread: \(unread)"
        unreadButton.setTitle(title, for: .normal)
        unreadButton.tintColor = unread > 0
        ? UIColor.systemBlue
        : UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)
    }
    
    private func updateRemoveButtonColor() {
        let color = ChaportSDK.shared.isChatVisible()
            ? UIColor.systemBlue
            : UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)

        removeButton.tintColor = color
    }
}

extension ViewController: ChaportSDKDelegate, ChaportSDKSwiftDelegate {
    func chatDidStart() {
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
    
    func chatDidPresent() {
        print("Chat presented")
        self.updateRemoveButtonColor()
    }
    
    func chatDidDismiss() {
        print("Chat dismissed")
        self.updateRemoveButtonColor()
    }
    
    func chatDidFail(error: Error) {
        print("Chat error: \(error)")
    }
    
    func unreadMessageDidChange(unreadInfo: ChaportUnreadMessageInfo) {
        unread = unreadInfo.count
        UIApplication.shared.applicationIconBadgeNumber = unreadInfo.count
        print("Unread message changed: \(unreadInfo)")
    }
    
    func linkDidClick(url: URL) -> ChaportLinkAction {
        print("Link clicked: \(url)")
        return .allow
    }
}
