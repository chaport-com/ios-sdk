import UIKit
import WebKit

@MainActor
protocol ChaportWebViewControllerDelegate: AnyObject {
    func webViewDidReceiveMessage(_ message: [String: Any])
}

class ChaportWebViewController: UIViewController, WKScriptMessageHandler {
    
    private let url: URL
    private var webView: WKWebView!
    private var onLoadCompletion: (() -> Void)?
    private var pendingMessages: [[String: Any]] = []
    private var isPageLoaded = false
    
    weak var delegate: ChaportWebViewControllerDelegate?
    
    var isChatVisible: Bool = false
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) не реализован")
    }
    
    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "nativeHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let sdkVersion = "1.0.4"
        let iosVersion = UIDevice.current.systemVersion
        config.applicationNameForUserAgent = "Chaport SDK \(sdkVersion) iOS \(iosVersion)"
        
        webView = WKWebView(frame: .zero, configuration: config)
        view = webView
    }
    
    func loadWebView(completion: @escaping () -> Void) {
        self.loadViewIfNeeded()

        let request = URLRequest(url: url)
        webView.load(request)
        webView.navigationDelegate = self
        self.onLoadCompletion = completion
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeHandler" {
            if let body = message.body as? [String: Any] {
                let visitorId = UserDefaults.standard.string(forKey: "chaportVisitorId") ?? ""

                if visitorId.isEmpty, let action = body["action"] as? String,
                    action == "emit",
                    let payload = body["payload"] as? [String: Any],
                    let name = payload["name"] as? String,
                    name == "session.start",
                    let data = payload["data"] as? [String: Any],
                    let visitorId = data["visitorId"] as? String {

                    UserDefaults.standard.set(visitorId, forKey: "chaportVisitorId")
                }

                delegate?.webViewDidReceiveMessage(body)
            }
        }
    }
    
    func evaluateJavaScript(message: [String: Any], completion: @escaping (Result<Any?, Error>) -> Void) {
        if !isPageLoaded {
            pendingMessages.append(message)
            return
        }

        let checkReadyScript = """
        (function() {
            return typeof window.chaport !== 'undefined' &&
                   typeof window.chaport.getChatManager === 'function';
        })()
        """
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: []),
                let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(ChaportSDKError.invalidResponse))
            return
        }
        
        let js = "window.chaportSdkBridge.receiveMessageFromSDK(\(jsonString));"

        webView.evaluateJavaScript(checkReadyScript) { result, error in
            let isReady = (result as? Bool) == true
            if isReady {
                self.webView.evaluateJavaScript(js) { (result, error) in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(result))
                    }
                }
            } else {
                completion(.failure(ChaportSDKError.invalidResponse))
            }
        }
    }
    
    // MARK: - Методы для вызова из ChaportSDK
    
    func startSession(with payload: [String: Any]) {
        let message: [String: Any] = ["action": "startSession", "payload": payload]
        evaluateJavaScript(message: message) { _ in}
    }
    
    func stopSession(completion: @escaping () -> Void) {
        let message: [String: Any] = ["action": "stopSession"]
        evaluateJavaScript(message: message) { [weak self] _ in
            self?.webView.stopLoading()
            completion()
        }
    }
    
    func setClosable(isClosable: Bool) {
        let message: [String: Any] = [
            "action": "setClosable",
            "payload": isClosable
        ]
        evaluateJavaScript(message: message) { _ in }
    }

    func setVisitorData(payload: [String: Any], hash: String) {
        let message: [String: Any] = [
            "action": "setVisitorData",
            "payload": [
                "visitor": payload,
                "hash": hash
            ]
        ]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func setDeviceToken(token: String) {
        let message: [String: Any] = ["action": "setDeviceToken", "payload": token]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func startBot(payload: [String: Any]) {
        let message: [String: Any] = ["action": "startBot", "payload": payload]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func canStartBot(botId: String?, completion: @escaping (Bool) -> Void) {
        var message: [String: Any] = ["action": "canStartBot"]
        if let botId = botId {
            message["payload"] = ["botId": botId]
        }
        evaluateJavaScript(message: message) { _ in }
    }
    
    func openFAQ() {
        let message: [String: Any] = ["action": "openFAQ"]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func openFAQArticle(articleSlug: String) {
        let message: [String: Any] = ["action": "openFAQArticle", "payload": ["articleSlug": articleSlug]]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func getUnreadMessage(completion: @escaping (String?, Int) -> Void) {
        let message: [String: Any] = ["action": "getUnreadMessage"]
        evaluateJavaScript(message: message) { result in
            switch result {
            case .success(let value):
                if let dict = value as? [String: Any],
                   let count = dict["count"] as? Int {
                    let lastMessage = dict["lastMessage"] as? String
                    completion(lastMessage, count)
                }
            case .failure(_):
                completion(nil, 0)
            }
        }
    }
}

extension ChaportWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageLoaded = true
        onLoadCompletion?()
        onLoadCompletion = nil
        
        for message in pendingMessages {
            evaluateJavaScript(message: message, completion: { _ in })
        }
        pendingMessages.removeAll()
    }
}
