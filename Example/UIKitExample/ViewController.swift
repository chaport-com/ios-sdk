import UIKit
import ChaportSDK

class ViewController: UIViewController, ChaportSDKDelegate {
    
    @IBOutlet weak var chat: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ChaportSDK.shared.delegate = self
        
        let sessionData: [String: Any] = ["persist": true]
        let config = Config(appId: "app_id", session: sessionData, region: "ru")
        // ����� configure
        ChaportSDK.shared.configure(config: config)
        // ����� setLanguage
        ChaportSDK.shared.setLanguage(languageCode: "ru")
        // ����� setVisitorData
        ChaportSDK.shared.setVisitorData(visitor: VisitorData(name: "Test", email: "local@email.ru", custom: ["field1": "---"]))
    }
    
    @IBAction func openChatModal(_ sender: Any) {
        // ������� ��� ��������
        ChaportSDK.shared.present(from: self)
    }
    
    @IBAction func openChatEmbed(_ sender: Any) {
        // ����� embed
        ChaportSDK.shared.embed(into: chat, parentViewController: self)
    }
    
    @IBAction func stopSession(_ sender: Any) {
        // ����� embed
        ChaportSDK.shared.stopSession()
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
        print("������ ����: \(error)")
    }
    
    func unreadMessageDidChange(unreadCount: Int, lastMessage: String?) {
        print("�������������: \(unreadCount), ���������: \(lastMessage ?? "")")
    }
    
    func linkDidClick(url: URL) {
        UIApplication.shared.open(url)
    }
}
