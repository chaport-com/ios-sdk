import UIKit
import Chaport

class ViewController: UIViewController, ChaportSDKDelegate {

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
    
    @IBAction func stopSession(_ sender: UIButton) {
        ChaportSDK.shared.stopSession() {
            self.setupVisitor()
        }
    }
    
    @IBAction func openFAQ(_ sender: UIButton) {
        ChaportSDK.shared.embed(into: chat, parentViewController: self)
        ChaportSDK.shared.openFAQ()
    }
    
    @IBAction func remove(_ sender: UIButton) {
        ChaportSDK.shared.remove()
    }
    
    // MARK: - ChaportSDKDelegate
    
    func chatDidStart() {
        print("chatDidStart")
        
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
        print("chatDidPresent")
        self.updateRemoveButtonColor()
    }
    
    func chatDidDismiss() {
        print("chatDidDismiss")
        self.updateRemoveButtonColor()
    }
    
    func chatDidFail(error: Error) {
        print("Chat did fail: \(error)")
    }
    
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
        unread = unreadCount
        print("Chat unreadMessageDidChange, unreadCount: \(unreadCount), lastMessage: \(lastMessage ?? "")")
    }
    
    func linkDidClick(url: URL) -> WebViewLinkAction {
        print("Chat did click link: \(url)")
        return .allow
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func setup() {
        var config = Config(appId: "0368d2dbb2abcef0d9facafa")

        ChaportSDK.shared.delegate = self
        ChaportSDK.shared.configure(config: config)
        
        setupVisitor()
    }
    
    private func setupVisitor() {
        ChaportSDK.shared.startSession()
        ChaportSDK.shared.setVisitorData(visitor: VisitorData(name: "Test SDK visitor"))
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
