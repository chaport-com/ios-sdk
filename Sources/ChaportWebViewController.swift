@preconcurrency import WebKit
import UIKit

@MainActor
@objc public protocol ChaportWebViewControllerDelegate: AnyObject {
    @objc optional func webViewDidReceiveMessage(_ message: [String: Any])
    @objc optional func webViewDidFailToLoad(error: Error)
    @objc optional func webViewLinkClicked(url: URL) -> WebViewLinkAction
}

class ChaportWebViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    
//    private let url: URL
    public var webViewInstance: WKWebView!
    private var pendingMessages: [[String: Any]] = []
    private var pendingRequestCompletions: [String: (Result<Any, Error>) -> Void] = [:]

    private var hasLoaded = false
    private var isLoading = false
    private var loadCompletions: [ (Result<Void, Error>) -> Void ] = []
    
    weak var delegate: ChaportWebViewControllerDelegate?
//    weak var sdkDelegate: ChaportSDKDelegate?
    weak var dataSource: ChaportWebViewDataSource?
    
//    var isChatVisible = false
//    var isPageLoaded = false
    
    init(dataSource: ChaportWebViewDataSource) {
//        self.url = url
        self.dataSource = dataSource
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) error")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//        print("webView didFinish 1")
        hasLoaded = true
        isLoading = false

//        print("webView didFinish 2")
        self.dataSource?.restoreWebView() { result in
//            print("webView didFinish 3")
            let completions = self.loadCompletions
            self.loadCompletions.removeAll()
            
            if case .success = result {
//                print("Sending pending messending")
                for message in self.pendingMessages {
                    self.evaluateJavaScript(message: message, completion: { _ in })
                }
                self.pendingMessages.removeAll()

//                print("webView didFinish end")
                completions.forEach { $0(.success(())) }
            } else {
                completions.forEach { $0(.failure(ChaportSDKError.webViewNotLoaded)) }
            }
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if navigationAction.navigationType == .other {
            decisionHandler(.allow)
            return
        }

        if let url = navigationAction.request.url {
            // Example: intercept all links
//            print("Attempting to navigate to: \(url.absoluteString)")
            
            let decision = delegate?.webViewLinkClicked?(url: url) ?? .allow
            
            if decision == .allow {
                UIApplication.shared.open(url)
            }
        }

        decisionHandler(.cancel)
    }
    
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {

        if navigationAction.targetFrame == nil {
            // It's a target=_blank (or similar)
            if let url = navigationAction.request.url {
                let decision = delegate?.webViewLinkClicked?(url: url) ?? .allow
                if decision == .allow {
                    UIApplication.shared.open(url)
                }
            }
        }

        return nil // Return nil to prevent creating a new webView
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailToLoad?(error: error)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailToLoad?(error: error)
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        let protectionSpace = challenge.protectionSpace

        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = protectionSpace.serverTrust {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "nativeHandler")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let sdkVersion = "1.0.9"
        let iosVersion = UIDevice.current.systemVersion
        config.applicationNameForUserAgent = "Chaport SDK \(sdkVersion) iOS \(iosVersion)"
        
        webViewInstance = WKWebView(frame: .zero, configuration: config)
        view = webViewInstance
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if self.dataSource?.onWebViewDidDisappear != nil {
            self.dataSource?.onWebViewDidDisappear()
        }
    }
    
    func loadWebView(completion: @escaping (Result<Void, Error>) -> Void) {
//        print("loadWebView 1")
        if hasLoaded {
            completion(.success(()))
            return
        }
        
//        print("loadWebView 2")

        if isLoading {
            loadCompletions.append(completion)
            return
        }
        
//        print("loadWebView 3")
        
        guard let dataSource = self.dataSource else {
            Logger.log("WebView data source is empty", level: .error)
            completion(.failure(ChaportSDKError.webViewNotLoaded))
            return
        }
        
//        print("loadWebView 4")
        
        guard let webViewURL = dataSource.webViewURL else {
            Logger.log("WebView URL is empty", level: .error)
            completion(.failure(ChaportSDKError.webViewNotLoaded))
            return
        }
        
//        print("loadWebView 5")

        isLoading = true
        loadCompletions.append(completion)

        loadViewIfNeeded()
        webViewInstance.navigationDelegate = self

        let request = URLRequest(url: webViewURL)
        webViewInstance.load(request)
        
//        print("loadWebView end")
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeHandler" {
            if let body = message.body as? [String: Any] {
                delegate?.webViewDidReceiveMessage?(body)
            }
        }
    }
    
    func evaluateJavaScript(message: [String: Any], completion: @escaping (Result<Any?, Error>) -> Void) {
        if !hasLoaded {
//            if let newAction = message["action"] as? String {
//                let alreadyQueued = pendingMessages.contains {
//                    ($0["action"] as? String) == newAction
//                }
//
//                if alreadyQueued {
//                    return
//                }
//            }
//            print("A new message pending \(message)")
            pendingMessages.append(message)
            return
        }
        
//        print(message)
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: []),
                let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(ChaportSDKError.invalidResponse))
            return
        }
        
        let js = "window.chaportSdkBridge.receiveMessageFromSDK(\(jsonString));"
        
//        print(js)

        self.webViewInstance.evaluateJavaScript(js) { (result, error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(result))
            }
        }
    }
    
    public func evaluateJavascriptWithResponse(message: [String: Any], completion: @escaping (Result<Any, Error>) -> Void) {
        var message = message
        let requestId = UUID().uuidString
        message["requestId"] = requestId
        
        pendingRequestCompletions[requestId] = completion

        self.evaluateJavaScript(message: message) { _ in }
    }
    
    public func resolvePendingRequest(message: [String: Any]) {
        if let requestId = message["requestId"] as? String,
           let completion = pendingRequestCompletions.removeValue(forKey: requestId) {
            DispatchQueue.main.async {
                if message["error"] != nil {
                    completion(.failure(
                        ChaportSDKError.chatError(payload: [:])))
                } else {
                    completion(.success(message["payload"] as? [String : Any] ?? [:]))
                }
            }
        }
    }
    
    // MARK: - Методы для вызова из ChaportSDK
    
    func startSession(payload: [String: Any]? = nil, completion: @escaping (Result<Void, Error>) -> Void) {
        var message: [String: Any] = ["action": "startSession"]
        if let payload = payload {
            message["payload"] = payload
        }
        
        evaluateJavascriptWithResponse(message: message) { result in
            switch result {
            case .success(_):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func stopSession(clearCache: Bool = true, completion: @escaping (Result<Void, Error>) -> Void) {
        let message: [String: Any] = ["action": "stopSession", "payload": clearCache]
        
        evaluateJavaScript(message: message) { result in
            switch result {
            case .success(_):
                completion(.success(()))
            case .failure(let error):
                completion(.failure(error))
            }
        }
//        self.webView.stopLoading()
    }
    
    func setClosable(isClosable: Bool) {
        let message: [String: Any] = [
            "action": "setClosable",
            "payload": isClosable
        ]
//        let message: [String: Any] = [
//            "action": "openFAQ"
//        ]
        evaluateJavaScript(message: message) { _ in }
    }

    func setVisitorData(visitorData: VisitorData, hash: String? = nil) {
        var visitorPayload: [String: Any] = [:]
        
        if let name = visitorData.name {
            visitorPayload["name"] = name
        }
        if let email = visitorData.email {
            visitorPayload["email"] = email
        }
        if let phone = visitorData.phone {
            visitorPayload["phone"] = phone
        }
        if let notes = visitorData.notes {
            visitorPayload["notes"] = notes
        }
        if let custom = visitorData.custom {
            visitorPayload["custom"] = custom
        }
        
        var payload: [String: Any] = ["visitor": visitorPayload]
        
        if let hash = hash {
            payload["hash"] = hash
        }

        let message: [String: Any] = [
            "action": "setVisitorData",
            "payload": payload
        ]
        
        evaluateJavaScript(message: message) { _ in }
    }
    
    func setDeviceToken(token: String) {
        let message: [String: Any] = ["action": "setDeviceToken", "payload": token]
        evaluateJavaScript(message: message) { _ in }
    }
    
    func startBot(botId: String, timestamp: Double) {
        let payload: [String: Any] = ["id": botId, "timestamp": timestamp]
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
                if let dict = value as? [String: Any], let count = dict["count"] as? Int {
                    let lastMessage = dict["lastMessage"] as? String
                    completion(lastMessage, count)
                }
            case .failure(_):
                completion(nil, 0)
            }
        }
    }
    
//    func startEvents() {
////        isChatVisible = true
//        for message in pendingMessages {
//            evaluateJavaScript(message: message, completion: { _ in })
//        }
//        pendingMessages.removeAll()
//    }
}
