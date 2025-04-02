import UIKit
import ChaportSDK

class ViewController: UIViewController, ChaportSDKDelegate {

    @IBOutlet weak var chat: UIView!
    @IBOutlet weak var unreadButton: UIButton!
    
    var unread: Int = 0 {
        didSet {
            updateUnreadLabel()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    @IBAction func openChatModal(_ sender: Any) {
        if !Chaport.shared.getStartSession() {
            setup()
        }
        
        Chaport.shared.present(from: self)
    }
    
    @IBAction func openChatEmbed(_ sender: Any) {
        if !Chaport.shared.getStartSession() {
            setup()
        }
        
        Chaport.shared.embed(into: chat, parentViewController: self)
    }
    
    @IBAction func stopSession(_ sender: Any) {
        Chaport.shared.stopSession()
    }
    
    @IBAction func openFAQ(_ sender: Any) {
        Chaport.shared.openFAQ()
    }
    
    @IBAction func remove(_ sender: Any) {
        Chaport.shared.remove()
    }
    
    // MARK: - ChaportSDKDelegate
    
    func chatDidStart() {
        print("chatDidStart")
    }
    
    func chatDidPresent() {
        print("chatDidPresent")
    }
    
    func chatDidDismiss() {
        print("chatDidDismiss")
    }
    
    func chatDidFail(error: Error) {
        print("Chat did fail: \(error)")
    }
    
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
        unread = unreadCount
        print("Chat unreadMessageDidChange, unreadCount: \(unreadCount), lastMessage: \(lastMessage ?? "")")
    }
    
    func canStartBot(isStart: Bool) {
        print("Can Start bot: \(isStart)")
    }
    
    func linkDidClick(url: URL) {
        print("Chat did click link: \(url)")
    }
    
    private func setup() {
        let config = Config(appId: "67ebdc851e966982eb469d50", session: ["persist": true], region: "ru")
        Chaport.shared.delegate = self
        Chaport.shared.configure(config: config)
        Chaport.shared.setLanguage(languageCode: "ru")
        Chaport.shared.startSession(details: UserDetails(id: "11111", token: "1345434234"))
        Chaport.shared.setVisitorData(visitor: VisitorData(name: "Test", email: "local@email.ru", phone: "+79992223344", notes: "Notes", custom: ["field1": "Test"]))
    }
    
    private func updateUnreadLabel() {
        let title = "Unread: \(unread)"
        unreadButton.setTitle(title, for: .normal)
    }
}
