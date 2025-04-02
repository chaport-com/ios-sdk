import UIKit
import WebKit

@MainActor
protocol ChaportWebViewControllerDelegate: AnyObject {
    func webViewDidReceiveMessage(_ message: [String: Any])
    func webViewDidFailToLoad(error: Error)
}

class ChaportWebViewController: UIViewController, WKScriptMessageHandler {
    
    private let url: URL
    private var webView: WKWebView!
    private var pendingMessages: [[String: Any]] = []
    
    weak var delegate: ChaportWebViewControllerDelegate?
    
    var isChatVisible = false
    var isPageLoaded = false
    
    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) error")
    }
    
    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "nativeHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let sdkVersion = "1.0.9"
        let iosVersion = UIDevice.current.systemVersion
        config.applicationNameForUserAgent = "Chaport SDK \(sdkVersion) iOS \(iosVersion)"
        
        webView = WKWebView(frame: .zero, configuration: config)
        view = webView
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed {
            self.isChatVisible = false
            Chaport.shared.delegate?.chatDidDismiss()
        }
    }
    
    func loadWebView(completion: @escaping () -> Void) {
        self.loadViewIfNeeded()
        let request = URLRequest(url: url)
        webView.load(request)
        webView.navigationDelegate = self
        completion()
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeHandler" {
            if let body = message.body as? [String: Any] {
                delegate?.webViewDidReceiveMessage(body)
            }
        }
    }
    
    func evaluateJavaScript(message: [String: Any], completion: @escaping (Result<Any?, Error>) -> Void) {
        if !isPageLoaded {
            if let newAction = message["action"] as? String {
                let alreadyQueued = pendingMessages.contains {
                    ($0["action"] as? String) == newAction
                }

                if alreadyQueued {
                    return
                }
            }

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
    
    func startSession(with payload: [String: Any]? = nil) {
        var message: [String: Any] = ["action": "startSession"]
        
        if let payload = payload {
            message["payload"] = payload
        }
        
        evaluateJavaScript(message: message) { _ in }
    }
    
    func stopSession(clearCache: Bool = true) {
        let message: [String: Any] = ["action": "stopSession", "payload": clearCache]
        evaluateJavaScript(message: message) { _ in }
        
        self.webView.stopLoading()
        self.isPageLoaded = false
        self.isChatVisible = false
    }
    
    func setClosable(isClosable: Bool) {
        let message: [String: Any] = [
            "action": "setClosable",
            "payload": isClosable
        ]
        evaluateJavaScript(message: message) { _ in }
    }

    func setVisitorData(payload: [String: Any], hash: String? = nil) {
        var visitorPayload: [String: Any] = ["visitor": payload]
        
        if let hash = hash {
            visitorPayload["hash"] = hash
        }

        let message: [String: Any] = [
            "action": "setVisitorData",
            "payload": visitorPayload
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
        let message: [String: Any] = ["action": "openFAQ", "payload": ["article": articleSlug]]
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
    
    func startEvents() {
        isChatVisible = true
        for message in pendingMessages {
            evaluateJavaScript(message: message, completion: { _ in })
        }
        pendingMessages.removeAll()
    }
}

extension ChaportWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isPageLoaded = true
       
        guard let startSessionData = pendingMessages.first(where: isStartSessionMessage) else { return }
        
        pendingMessages.removeAll(where: isStartSessionMessage)
        evaluateJavaScript(message: startSessionData) { _ in }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailToLoad(error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailToLoad(error: error)
    }
    
    private func isStartSessionMessage(_ data: [String: Any]) -> Bool {
        return data["action"] as? String == "startSession"
    }
}
