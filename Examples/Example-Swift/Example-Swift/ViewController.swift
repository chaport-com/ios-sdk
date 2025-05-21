import UIKit

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
        Chaport.shared.present(from: self)
    }
    
    @IBAction func openChatEmbed(_ sender: UIButton) {
        Chaport.shared.embed(into: chat, parentViewController: self)
    }
    
    @IBAction func stopSession(_ sender: UIButton) {
        Chaport.shared.stopSession() {
            self.setupVisitor()
        }
    }
    
    @IBAction func openFAQ(_ sender: UIButton) {
        Chaport.shared.embed(into: chat, parentViewController: self)
        Chaport.shared.openFAQ()
    }
    
    @IBAction func remove(_ sender: UIButton) {
        Chaport.shared.remove()
    }
    
    // MARK: - ChaportSDKDelegate
    
    func chatDidStart() {
        print("chatDidStart")
        self.updateRemoveButtonColor()
        
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
        self.updateRemoveButtonColor()
    }
    
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
        unread = unreadCount
        print("Chat unreadMessageDidChange, unreadCount: \(unreadCount), lastMessage: \(lastMessage ?? "")")
    }
    
    func linkDidClick(url: URL) {
        print("Chat did click link: \(url)")
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    private func setup() {
        var config = Config(appId: "5f1934c97b03b95bf88d284a")
        config["region"] = "local"
//        var config = Config(appId: "07da6b4daf891330f3354098")
//        config["region"] = "ru"
        Chaport.shared.delegate = self
        Chaport.shared.configure(config: config)
        
        setupVisitor()
    }
    
    private func setupVisitor() {
//        Chaport.shared.setLanguage(languageCode: "ru")
        Chaport.shared.startSession()
        Chaport.shared.setVisitorData(visitor: VisitorData(name: "Test SDK visitor", custom: ["field1": "Test"]))
    }
    
    private func updateUnreadLabel() {
        let title = "Unread: \(unread)"
        unreadButton.setTitle(title, for: .normal)
        unreadButton.tintColor = unread > 0
        ? UIColor.systemBlue
        : UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)
    }
    
    private func updateRemoveButtonColor() {
        let color = Chaport.shared.isChatVisible()
            ? UIColor.systemBlue
            : UIColor(red: 0xCC / 255.0, green: 0xCC / 255.0, blue: 0xD0 / 255.0, alpha: 1.0)

        removeButton.tintColor = color
    }
}
